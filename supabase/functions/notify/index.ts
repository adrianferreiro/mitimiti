// Recibe los cambios que mandan los triggers de
// supabase/migrations/20261001120000_push_notifications.sql y avisa por FCM
// a los demás miembros del grupo.
//
// Secretos de la función:
// - NOTIFY_SECRET: el mismo valor que `notify_secret` en Vault.
// - FIREBASE_SERVICE_ACCOUNT: JSON de la cuenta de servicio de Firebase.
// Se despliega con --no-verify-jwt (la llamada viene de la base, no de un
// usuario); la autenticación es el header x-notify-secret.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type Row = Record<string, string | number | null>;

interface Change {
  table: "expenses" | "settlements" | "group_members";
  type: "INSERT" | "UPDATE" | "DELETE";
  record: Row | null;
  old_record: Row | null;
  actor: string | null;
}

interface Push {
  userId: string;
  title: string;
  body: string;
  groupId: string;
}

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.headers.get("x-notify-secret") !== Deno.env.get("NOTIFY_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  const change = (await req.json()) as Change;
  const pushes = await buildPushes(change);
  await Promise.all(pushes.map(send));
  return new Response(JSON.stringify({ sent: pushes.length }), {
    headers: { "Content-Type": "application/json" },
  });
});

// ---------------------------------------------------------------------------
// Qué avisar y a quién
// ---------------------------------------------------------------------------

async function buildPushes(c: Change): Promise<Push[]> {
  const row = (c.record ?? c.old_record)!;
  const groupId = row.group_id as string;
  const [groupName, memberIds] = await Promise.all([
    loadGroupName(groupId),
    loadMemberIds(groupId),
  ]);

  if (c.table === "expenses") {
    const recipients = memberIds.filter((id) => id !== c.actor);
    const names = await loadNames([c.actor, row.paid_by as string]);
    const actor = nameOf(names, c.actor);
    const what = await describeExpense(row);
    let body: string;
    if (c.type === "INSERT") {
      body = `${actor} anotó ${what}`;
      if (row.paid_by !== c.actor) {
        body += ` (pagó ${nameOf(names, row.paid_by as string)})`;
      }
    } else if (c.type === "UPDATE") {
      body = `${actor} editó un gasto: ${what}`;
    } else {
      body = `${actor} borró un gasto: ${what}`;
    }
    return recipients.map((userId) => ({ userId, title: groupName, body, groupId }));
  }

  if (c.table === "settlements" && c.type === "INSERT") {
    const from = row.from_user_id as string;
    const to = row.to_user_id as string;
    const names = await loadNames([c.actor, from, to]);
    const amount = formatCents(Number(row.amount_cents));
    const pushes: Push[] = [];
    if (to !== c.actor) {
      const body = c.actor === from
        ? `${nameOf(names, from)} te pagó ${amount}`
        : `${nameOf(names, c.actor)} registró que ${nameOf(names, from)} te pagó ${amount}`;
      pushes.push({ userId: to, title: groupName, body, groupId });
    }
    if (from !== c.actor) {
      const body = c.actor === to
        ? `${nameOf(names, to)} registró que le pagaste ${amount}`
        : `${nameOf(names, c.actor)} registró que le pagaste ${amount} a ${nameOf(names, to)}`;
      pushes.push({ userId: from, title: groupName, body, groupId });
    }
    return pushes;
  }

  if (c.table === "group_members" && c.type === "INSERT") {
    const joined = row.user_id as string;
    const names = await loadNames([joined]);
    const body = `${nameOf(names, joined)} se unió al grupo`;
    return memberIds
      .filter((id) => id !== joined)
      .map((userId) => ({ userId, title: groupName, body, groupId }));
  }

  return [];
}

async function loadGroupName(groupId: string): Promise<string> {
  const { data } = await db.from("groups").select("name").eq("id", groupId)
    .maybeSingle();
  return data?.name ?? "mitimiti";
}

async function loadMemberIds(groupId: string): Promise<string[]> {
  const { data } = await db.from("group_members").select("user_id")
    .eq("group_id", groupId);
  return (data ?? []).map((m) => m.user_id as string);
}

async function loadNames(
  ids: (string | null)[],
): Promise<Map<string, string>> {
  const wanted = [...new Set(ids.filter((id): id is string => id != null))];
  const { data } = await db.from("profiles").select("id, display_name")
    .in("id", wanted);
  return new Map((data ?? []).map((p) => [p.id, p.display_name]));
}

function nameOf(names: Map<string, string>, id: string | null): string {
  return (id && names.get(id)) || "Alguien";
}

// "$12.500 en Supermercado · Pan y leche"
async function describeExpense(row: Row): Promise<string> {
  const { data } = await db.from("categories").select("name")
    .eq("id", row.category_id as string).maybeSingle();
  let text = formatCents(Number(row.amount_cents));
  if (data?.name) text += ` en ${data.name}`;
  const description = String(row.description ?? "").trim();
  if (description) text += ` · ${description}`;
  return text;
}

// Igual que formatCents de lib/domain/money.dart: "$12.500" o "$12.500,50".
function formatCents(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const pesos = Math.floor(abs / 100).toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const rest = abs % 100;
  const decimals = rest === 0 ? "" : `,${rest.toString().padStart(2, "0")}`;
  return `${sign}$${pesos}${decimals}`;
}

// ---------------------------------------------------------------------------
// Envío por FCM (API HTTP v1)
// ---------------------------------------------------------------------------

const serviceAccount = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}",
) as { project_id: string; client_email: string; private_key: string };

let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const key = await importPKCS8(serviceAccount.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`OAuth de Google falló: ${JSON.stringify(json)}`);
  cachedToken = { value: json.access_token, expiresAt: now + json.expires_in };
  return cachedToken.value;
}

async function send(push: Push): Promise<void> {
  const { data } = await db.from("device_tokens").select("token")
    .eq("user_id", push.userId);
  const tokens = (data ?? []).map((t) => t.token as string);
  if (tokens.length === 0) return;

  const auth = await accessToken();
  const url =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  await Promise.all(tokens.map(async (token) => {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${auth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: push.title, body: push.body },
          data: { group_id: push.groupId },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (res.ok) return;
    const error = await res.text();
    // Token de una app desinstalada o vencido: se borra para no reintentar.
    if (res.status === 404 || error.includes("UNREGISTERED")) {
      await db.from("device_tokens").delete().eq("token", token);
    } else {
      console.error(`FCM ${res.status} para ${push.userId}: ${error}`);
    }
  }));
}
