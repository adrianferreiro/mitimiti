# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Producto

**mitimiti** es una app Flutter (Android/iOS) para registrar gastos compartidos entre personas.

- Cada usuario anota los gastos que pagó, con categoría.
- La app muestra el detalle de lo que gastó cada uno (por persona y por categoría).
- **Función principal:** calcular el saldo — quién le debe a quién y cuánto — para que el total gastado quede repartido en partes iguales (50/50 en el caso inicial).
- Caso de uso inicial: gastos comunes del departamento de una pareja (2 personas). La intención es escalar después, así que el modelo de dominio no debería asumir exactamente dos participantes ni un reparto fijo del 50% cuando pueda evitarse (pensar en grupos de N personas y en repartos configurables).

## Decisiones tomadas (MVP)

- Backend: **Supabase** (proyecto `kzfrtssvigmeitwiicyx`). URL y publishable key en `lib/config.dart` (públicas por diseño; la seguridad la da RLS).
- Auth: **email + contraseña, sin confirmación de email** ("Confirm email" desactivado en el dashboard) para no depender de SMTP en el MVP. Sin SMTP no hay recuperación de contraseña: se resetea a mano desde el dashboard. Más adelante: SMTP propio + código por email.
- Moneda única: **ARS**. Montos siempre como `int` en centavos, nunca `double`.
- Saldar deudas se registra como un `Settlement`; nunca se borran ni modifican gastos para cerrar el balance.

## Arquitectura

- `lib/domain/`: Dart puro, sin imports de Flutter ni de Supabase. Es el corazón de la app y debe mantenerse testeable en aislamiento (`test/domain/`).
  - `models/`: `Expense`, `Settlement`, `Category`, `Group`, `Member` (inmutables, validan en el constructor).
  - `money.dart`: `formatCents` ("$12.500,50") y `parseCents` (lo que escribe el usuario → centavos; coma decimal, punto de miles). Toda entrada/salida de montos pasa por acá.
  - `balance.dart`: `netBalances` calcula el saldo neto por miembro (`pagado − su parte + pagos enviados − pagos recibidos`; positivo = le deben). Cada gasto se reparte en partes iguales entre todos los miembros y **el que pagó absorbe los centavos sobrantes**, así la suma de saldos es siempre 0. `simplifyDebts` convierte saldos en transferencias sugeridas (mayor deudor ↔ mayor acreedor, desempate por id). `paidTotals` suma lo pagado por cada uno.
- `supabase/migrations/`: esquema versionado (fuente de verdad de la base). Cambios al esquema = nueva migración, nunca editar una ya aplicada. Columnas en snake_case (`amount_cents`, `spent_on`, `settled_on`) que se mapean a los modelos de `lib/domain/`.
  - RLS en todas las tablas; el acceso se decide con `is_group_member(group_id)`.
  - El proyecto no expone tablas nuevas automáticamente: toda tabla nueva necesita `grant ... to authenticated` explícito además de sus políticas RLS.
  - Grupos y membresías **solo** se crean vía RPC: `create_group(group_name)` (agrega al creador y categorías por defecto) y `join_group(code)` (código de invitación de 6 caracteres).
  - FKs compuestas garantizan que quien paga/cobra sea miembro del grupo y que la categoría sea del mismo grupo.
- `lib/data/`: repositorios sobre `supabase_flutter` (`AuthRepository`, `GroupsRepository`, `GroupDataRepository`) que mapean filas a modelos de `lib/domain/` y traducen errores de Supabase a `AppException` con mensaje en castellano para mostrar al usuario.
  - `GroupDataRepository.load` trae miembros, categorías, gastos y pagos de un grupo en un solo `GroupData`; las pantallas del grupo recargan todo después de cada cambio propio, ante cambios en vivo (`watch`: Realtime sobre `expenses`, `settlements` y `group_members`; los DELETE no se pueden filtrar por grupo, así que cualquier borrado dispara recarga) y al volver a la app desde segundo plano.
- `lib/ui/`: pantallas (`auth/`, `groups/`, `expenses/`). El grupo tiene pestañas Gastos, Resumen y Saldo. Gastos y Resumen se filtran por mes (`lib/domain/summary.dart`); el Saldo es siempre de todo el historial y se calcula en el cliente con `lib/domain/balance.dart`. Si el usuario tiene un solo grupo, se abre directo al iniciar. App fija en `es_AR` (`flutter_localizations`). Reciben los repositorios por constructor (sin paquete de state management por ahora); en los tests se reemplazan por fakes con `implements` (`test/ui/fakes.dart`).
- `lib/app.dart`: `MaterialApp` que muestra login o la lista de grupos según `AuthRepository.signedInChanges`. `lib/main.dart` inicializa Supabase y arma los repositorios.

## Comandos

```bash
flutter pub get                          # instalar dependencias
flutter run                              # correr en el dispositivo/emulador conectado
flutter analyze                          # lint (flutter_lints, ver analysis_options.yaml)
flutter test                             # todos los tests
flutter test test/ui/login_screen_test.dart  # un archivo
flutter test --plain-name "registro"     # tests cuyo nombre contiene el texto
dart format .                            # formatear
```

- SDK de Dart: `^3.13.2` (ver `pubspec.yaml`).
- El análisis estático excluye `build/`, `android/` e `ios/`.
- Package name para imports: `package:mitimiti/...`. El application id de Android sigue siendo `com.example.mitimiti`.
