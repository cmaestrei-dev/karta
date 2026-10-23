import 'package:flutter/material.dart';

/// Paleta «Cal y azulejo»: muro encalado, tinta de azulejo y colores de fachada.
/// Los colores de fachada son código (tipo de ruta, riesgo, categoría), nunca adorno.
abstract final class KartaColors {
  static const cal = Color(0xFFFBFAF6);
  static const tinta = Color(0xFF1B1B1F);
  static const tintaSuave = Color(0xFF4A4B55);
  static const cobalto = Color(0xFF1D3A8A);

  // Precaución y peligro: tráfico y seguridad, riesgo medio y alto.
  static const ocre = Color(0xFFE3A72F);
  static const tintaSobreOcre = Color(0xFF2A1E00);
  static const ladrillo = Color(0xFFB23A26);
  static const ladrilloProfundo = Color(0xFF7F1D12);
  static const balcon = Color(0xFF2E7D4F);

  // Tipos de ruta de Transcaribe. Todos admiten texto blanco con contraste ≥ 4,5:1 y ninguno
  // repite el cobalto de la interfaz ni los colores de riesgo: una cápsula nunca parece un botón
  // ni una alerta.
  static const troncal = Color(0xFF0B6E6E); // verde mar
  static const pretroncal = Color(0xFFA61E5A);
  static const alimentadora = Color(0xFF7A4A1C); // madera de balcón
  static const complementaria = Color(0xFF5B3A8C);
}

/// Cifras de ancho fijo: los minutos y metros de distintas opciones quedan alineados.
const tabularFigures = [FontFeature.tabularFigures()];

abstract final class KartaTheme {
  static const _serif = 'SourceSerif';

  static const _claro = ColorScheme(
    brightness: Brightness.light,
    primary: KartaColors.cobalto,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCE3F7),
    onPrimaryContainer: Color(0xFF0D1F52),
    secondary: KartaColors.ocre,
    onSecondary: KartaColors.tintaSobreOcre,
    secondaryContainer: Color(0xFFFBE7BC),
    onSecondaryContainer: KartaColors.tintaSobreOcre,
    tertiary: KartaColors.balcon,
    onTertiary: Colors.white,
    error: KartaColors.ladrillo,
    onError: Colors.white,
    errorContainer: Color(0xFFF8DCD6),
    onErrorContainer: KartaColors.ladrilloProfundo,
    surface: KartaColors.cal,
    onSurface: KartaColors.tinta,
    onSurfaceVariant: KartaColors.tintaSuave,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF6F4EE),
    surfaceContainer: Color(0xFFF0EEE7),
    surfaceContainerHigh: Color(0xFFEAE7DF),
    surfaceContainerHighest: Color(0xFFE3E0D7),
    outline: Color(0xFF75767F),
    outlineVariant: Color(0xFFD5D2C8),
    inverseSurface: Color(0xFF2F3036),
    onInverseSurface: Color(0xFFF2F0E9),
    inversePrimary: Color(0xFFB7C6F5),
    surfaceTint: KartaColors.cobalto,
  );

  static const _oscuro = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB7C6F5),
    onPrimary: Color(0xFF0D1F52),
    primaryContainer: Color(0xFF2B4796),
    onPrimaryContainer: Color(0xFFDCE3F7),
    secondary: Color(0xFFF0C064),
    onSecondary: KartaColors.tintaSobreOcre,
    secondaryContainer: Color(0xFF5C4300),
    onSecondaryContainer: Color(0xFFFBE7BC),
    tertiary: Color(0xFF8FD3A8),
    onTertiary: Color(0xFF003920),
    error: Color(0xFFFFB4A6),
    onError: Color(0xFF5F1206),
    errorContainer: Color(0xFF8E2A19),
    onErrorContainer: Color(0xFFFFDAD3),
    surface: Color(0xFF12141B),
    onSurface: Color(0xFFE6E4DD),
    onSurfaceVariant: Color(0xFFC6C6D0),
    surfaceContainerLowest: Color(0xFF0D0F15),
    surfaceContainerLow: Color(0xFF1A1C23),
    surfaceContainer: Color(0xFF1E2028),
    surfaceContainerHigh: Color(0xFF282A32),
    surfaceContainerHighest: Color(0xFF33353D),
    outline: Color(0xFF90909A),
    outlineVariant: Color(0xFF45464F),
    inverseSurface: Color(0xFFE6E4DD),
    onInverseSurface: Color(0xFF2F3036),
    inversePrimary: KartaColors.cobalto,
    surfaceTint: Color(0xFFB7C6F5),
  );

  static ThemeData get claro => _construir(_claro);
  static ThemeData get oscuro => _construir(_oscuro);

  /// Superficie de una placa de azulejo: blanca de día, un escalón sobre el fondo de noche.
  static Color azulejo(ColorScheme scheme) =>
      scheme.brightness == Brightness.light ? scheme.surfaceContainerLowest : scheme.surfaceContainerHigh;

  static ThemeData _construir(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final texto = base.textTheme;
    TextStyle? serif(TextStyle? estilo, FontWeight peso) =>
        estilo?.copyWith(fontFamily: _serif, fontWeight: peso, letterSpacing: 0);

    final textTheme = texto.copyWith(
      displaySmall: serif(texto.displaySmall, FontWeight.w700),
      headlineLarge: serif(texto.headlineLarge, FontWeight.w700),
      headlineMedium: serif(texto.headlineMedium, FontWeight.w700),
      headlineSmall: serif(texto.headlineSmall, FontWeight.w700),
      titleLarge: serif(texto.titleLarge, FontWeight.w600),
      titleMedium: serif(texto.titleMedium, FontWeight.w600),
    );
    final botonForma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const botonTamano = Size(64, 48);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: botonTamano, shape: botonForma, textStyle: texto.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: botonTamano,
          shape: botonForma,
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: botonForma),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        extendedTextStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: azulejo(scheme),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: texto.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        titleTextStyle: texto.bodyLarge?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
    );
  }
}
