# mitimiti

App Flutter (Android / iOS) para registrar gastos compartidos y calcular quién le debe a quién. Backend en Supabase.

## Preparar el entorno

```bash
flutter pub get
```

- **iOS:** Xcode con el Apple ID de la cuenta logueado (Xcode → Settings → Accounts). La firma es automática (Team `822QP5S5Y9`).
- **Android:** para firmar los builds de release hace falta la upload key (ver abajo).

### Upload key de Android (una vez por máquina)

1. Copiar `mitimiti-upload.jks` (está guardado fuera del repo) a la máquina, por ejemplo en `~/mitimiti-upload.jks`.
2. Crear `android/key.properties` a partir de la plantilla y completar las contraseñas y la ruta **absoluta** del `.jks`:

   ```bash
   cp android/key.properties.example android/key.properties
   ```

Sin `android/key.properties` el build de release se firma con la clave de debug de la máquina (lo avisa en la salida). Ese APK no se instala encima de uno firmado con la upload key.

> La clave se creó una sola vez con:
> `keytool -genkey -v -keystore ~/mitimiti-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
> No volver a crearla: una clave nueva no puede actualizar la app ya instalada ni publicada.

## Generar builds

**Antes de cada build que se distribuya**, subir el número de build en `pubspec.yaml`:

```yaml
version: 1.0.0+3   # → 1.0.0+4
```

`1.0.0` es la versión visible; `+N` es el número de build. Tiene que crecer siempre (Apple y Google rechazan números repetidos).

### APK (Android, para pasar al QA)

```bash
flutter build apk --release
```

Sale en `build/app/outputs/flutter-apk/app-release.apk` (~55 MB, sirve para cualquier Android).

Versión más liviana, un APK por arquitectura:

```bash
flutter build apk --release --split-per-abi
```

Para casi cualquier Android actual sirve `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~20 MB).

### App Bundle (Android, para Google Play)

```bash
flutter build appbundle --release
```

Sale en `build/app/outputs/bundle/release/app-release.aab`. Es el formato que se sube a Play Console (no se instala directo en un teléfono). Tiene que estar firmado con la upload key.

### IPA (iOS, para TestFlight / App Store)

```bash
flutter build ipa --release
```

El `.ipa` queda en `build/ios/ipa/`. Para subirlo:

1. Abrir **Transporter** (Mac App Store), iniciar sesión con el Apple ID y arrastrar el `.ipa` → **Entregar**.
2. En App Store Connect → mitimiti → **TestFlight**, esperar a que termine de procesar (5–30 min).
3. Asignar el build a los grupos de testers.

Si falla por firma: abrir `ios/Runner.xcworkspace` en Xcode → Runner → **Signing & Capabilities** → revisar el Team y que esté activo "Automatically manage signing".

## Íconos y splash

Si cambia el logo (`assets/branding/`), regenerar:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
