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
- Auth: **email + contraseña, sin confirmación de email** ("Confirm email" desactivado en el dashboard) para no depender de SMTP en el MVP. Sin SMTP no hay "olvidé mi contraseña": se resetea a mano desde el dashboard. Logueado sí se puede cambiar (Mi cuenta). Más adelante: SMTP propio + código por email.
- Moneda única: **ARS**. Montos siempre como `int` en centavos, nunca `double`.
- Saldar deudas se registra como un `Settlement`; nunca se borran ni modifican gastos para cerrar el balance.

## Arquitectura

- `lib/domain/`: Dart puro, sin imports de Flutter ni de Supabase. Es el corazón de la app.
  - `models/`: `Expense`, `Settlement`, `Category`, `Group`, `Member` (inmutables, validan en el constructor).
  - `money.dart`: `formatCents` ("$12.500,50") y `parseCents` (lo que escribe el usuario → centavos; coma decimal, punto de miles). Toda entrada/salida de montos pasa por acá.
  - `balance.dart`: `netBalances` calcula el saldo neto por miembro (`pagado − su parte + pagos enviados − pagos recibidos`; positivo = le deben). Cada gasto se reparte en partes iguales entre todos los miembros y **el que pagó absorbe los centavos sobrantes**, así la suma de saldos es siempre 0. `simplifyDebts` convierte saldos en transferencias sugeridas (mayor deudor ↔ mayor acreedor, desempate por id). `paidTotals` suma lo pagado por cada uno.
- `supabase/migrations/`: esquema versionado (fuente de verdad de la base). Cambios al esquema = nueva migración, nunca editar una ya aplicada. Columnas en snake_case (`amount_cents`, `spent_on`, `settled_on`) que se mapean a los modelos de `lib/domain/`.
  - RLS en todas las tablas; el acceso se decide con `is_group_member(group_id)`.
  - El proyecto no expone tablas nuevas automáticamente: toda tabla nueva necesita `grant ... to authenticated` explícito además de sus políticas RLS.
  - Grupos y membresías **solo** se crean vía RPC: `create_group(group_name)` (agrega al creador y categorías por defecto) y `join_group(code)` (código de invitación de 6 caracteres).
  - FKs compuestas garantizan que quien paga/cobra sea miembro del grupo y que la categoría sea del mismo grupo.
- `lib/data/`: repositorios sobre `supabase_flutter` (`AuthRepository`, `GroupsRepository`, `GroupDataRepository`, `ProfileRepository`) que mapean filas a modelos de `lib/domain/` y traducen errores de Supabase a `AppException` con mensaje en castellano para mostrar al usuario.
  - Errores de Postgres que el usuario puede provocar se traducen por código: `23505` (nombre de categoría repetido) y `23503` (FK: borrar una categoría con gastos, o salir de un grupo con gastos/pagos propios; las FKs compuestas a `group_members` lo impiden a propósito para no romper el saldo de los demás).
  - `GroupDataRepository.load` trae miembros, categorías, gastos y pagos de un grupo en un solo `GroupData`; las pantallas del grupo recargan todo después de cada cambio propio, ante cambios en vivo (`watch`: Realtime sobre `expenses`, `settlements` y `group_members`; los DELETE no se pueden filtrar por grupo, así que cualquier borrado dispara recarga) y al volver a la app desde segundo plano.
- `lib/ui/`: pantallas (`auth/`, `account/`, `groups/`, `expenses/`); diálogos reutilizables en `lib/ui/dialogs.dart` (`showTextPrompt`, `confirm`). El menú ⋯ del grupo tiene renombrar, categorías, mi cuenta y salir. El grupo tiene pestañas Gastos, Resumen y Saldo. Gastos y Resumen se filtran por mes (`lib/domain/summary.dart`); el Saldo es siempre de todo el historial y se calcula en el cliente con `lib/domain/balance.dart`. Si el usuario tiene un solo grupo, se abre directo al iniciar. App fija en `es_AR` (`flutter_localizations`).
- `lib/ui/theme.dart`: tema único claro estilo app de finanzas: fondo menta pálido (`AppColors.background`), tarjetas y campos blancos, lima suave (`AppColors.lime`) como acento (pestaña activa en píldora, tarjeta de saldo/resumen, login), negro (`AppColors.ink`) para texto, botones y tarjeta destacada; "le deben" en `AppColors.positive`, deudas/errores en `AppColors.red`. `HighlightCard` (negra o lima) para los totales; `lib/ui/category_icon.dart` asigna ícono por nombre de categoría. Tipografía Plus Jakarta Sans empaquetada en `assets/fonts/` (licencia OFL incluida). Usar `AppColors` / `Theme.of(context)` en vez de colores sueltos y no fijar bordes en cada `InputDecoration`.
- `lib/app.dart`: `MaterialApp` que muestra login o la lista de grupos según `AuthRepository.signedInChanges`. `lib/main.dart` inicializa Supabase y arma los repositorios.

## Pruebas

- **No generar tests** (ni unitarios, ni de widgets, ni de integración) y **no ejecutar pruebas**: nada de `flutter test`, capturas, builds o consultas SQL para verificar cambios. Las pruebas las hace el usuario.
- Al terminar un cambio, decir qué conviene probar en vez de probarlo.

## Comandos

```bash
flutter pub get                          # instalar dependencias
flutter run                              # correr en el dispositivo/emulador conectado
flutter analyze                          # lint (flutter_lints, ver analysis_options.yaml)
dart format .                            # formatear
```

- SDK de Dart: `^3.13.2` (ver `pubspec.yaml`).
- El análisis estático excluye `build/`, `android/` e `ios/`.
- Package name para imports: `package:mitimiti/...`. Application id (Android) y bundle id (iOS): `com.adrianferreiro.mitimiti`. No cambiarlo una vez publicada la app en las tiendas.
