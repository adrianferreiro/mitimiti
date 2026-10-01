import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de mitimiti, tomada del logo (assets/branding/logo_source.png):
/// azul marino ("tinta") para texto, botones y tarjetas destacadas, verde
/// agua como acento, coral para deudas, sobre un fondo verde agua muy pálido
/// con tarjetas blancas.
abstract final class AppColors {
  /// Fondo de las pantallas.
  static const background = Color(0xFFEDF7F3);

  /// Tarjetas, campos y botones circulares.
  static const surface = Color(0xFFFFFFFF);

  /// Campo de texto con foco.
  static const surfaceFocused = Color(0xFFF4FBF8);

  /// Bordes suaves y divisores.
  static const outline = Color(0xFFDCEBE5);

  /// Verde agua del logo: pestaña activa, tarjeta de saldo, chips, avatares.
  static const accent = Color(0xFF36D2AF);

  /// Verde agua claro para fondos de barras y resaltados suaves.
  static const accentTint = Color(0xFFD3F4EB);

  /// Coral del logo (la otra persona del símbolo).
  static const coral = Color(0xFFFD835E);

  /// Azul marino del logo: texto, botón principal, tarjeta destacada,
  /// íconos de categoría, splash y login.
  static const ink = Color(0xFF1C2233);

  /// Texto e íconos sobre [ink].
  static const onInk = Color(0xFFFFFFFF);

  static const textMuted = Color(0xFF5E6678);

  /// "Le deben": verde agua oscuro, legible sobre blanco.
  static const positive = Color(0xFF128A6C);

  /// "Debe" y errores: coral oscuro, legible sobre blanco.
  static const red = Color(0xFFD9542F);
}

const _font = 'PlusJakartaSans';

const _fieldBorder = UnderlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(18)),
  borderSide: BorderSide.none,
);

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.ink,
    onPrimary: AppColors.onInk,
    primaryContainer: AppColors.accent,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.accent,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.positive,
    onTertiary: AppColors.onInk,
    error: AppColors.red,
    onError: AppColors.onInk,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.surface,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.onInk,
    inversePrimary: AppColors.accent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: AppColors.background,
  );

  // Títulos pesados y compactos; cuerpo legible.
  final text = base.textTheme
      .copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      )
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  const pill = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  final rounded18 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.onInk,
        disabledBackgroundColor: AppColors.outline,
        disabledForegroundColor: AppColors.textMuted,
        shape: pill,
        padding: buttonPadding,
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.outline, width: 1.5),
        shape: pill,
        padding: buttonPadding,
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.onInk,
      elevation: 0,
      highlightElevation: 0,
      shape: pill,
    ),
    // Pestañas como en "Today / Weekly / Monthly": la activa es una píldora
    // verde agua.
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      indicator: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    // Campos blancos sin borde. Se usa UnderlineInputBorder invisible (y no
    // OutlineInputBorder) para que la etiqueta flotante quede dentro de la
    // caja.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? AppColors.surfaceFocused
            : AppColors.surface,
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? AppColors.red
              : states.contains(WidgetState.focused)
              ? AppColors.ink
              : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixStyle: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      errorStyle: const TextStyle(
        color: AppColors.red,
        fontWeight: FontWeight.w600,
      ),
      border: _fieldBorder,
      enabledBorder: _fieldBorder,
      focusedBorder: _fieldBorder,
      errorBorder: _fieldBorder,
      focusedErrorBorder: _fieldBorder,
      disabledBorder: _fieldBorder,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.ink,
      selectionColor: AppColors.accentTint,
      selectionHandleColor: AppColors.ink,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(rounded18),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.ink,
      titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      subtitleTextStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
      shape: rounded18,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.titleLarge,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.accent,
      headerForegroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      todayBorder: const BorderSide(color: AppColors.ink, width: 1.5),
      dayBackgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.ink
            : Colors.transparent,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onInk),
      shape: rounded18,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.accentTint,
      circularTrackColor: Colors.transparent,
    ),
    bannerTheme: const MaterialBannerThemeData(
      backgroundColor: AppColors.accentTint,
    ),
    // Botones de ícono en círculo blanco, como la campana de la referencia.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.5),
        shape: const CircleBorder(),
      ),
    ),
  );
}

/// Color del avatar de un miembro: verde agua para uno mismo y coral para
/// los demás, como las dos personas del logo.
Color memberColor({required bool isMe}) =>
    isMe ? AppColors.accent : AppColors.coral;

/// Tarjeta destacada (total, saldo): fondo azul marino o verde agua, sin
/// borde.
class HighlightCard extends StatelessWidget {
  const HighlightCard({
    super.key,
    required this.child,
    this.dark = true,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;

  /// `true`: azul marino con texto blanco. `false`: verde agua con texto
  /// azul marino.
  final bool dark;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.onInk : AppColors.ink;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : AppColors.accent,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: child,
        ),
      ),
    );
  }
}
