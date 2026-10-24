import 'package:flutter/material.dart';

import 'bahia.dart';

/// Tema «Bahía» de toda la app: Material 3 con los tokens de [Bahia] y Manrope.
abstract final class TemaBahia {
  static ThemeData get oscuro => _construir(Bahia.oscura, Brightness.dark);
  static ThemeData get claro => _construir(Bahia.clara, Brightness.light);

  static ThemeData _construir(Bahia b, Brightness brillo) {
    final esquema = ColorScheme(
      brightness: brillo,
      primary: b.acento,
      onPrimary: b.sobreAcento,
      primaryContainer: b.acentoSuave,
      onPrimaryContainer: b.texto,
      secondary: b.reportar,
      onSecondary: b.sobreReportar,
      tertiary: b.enVivo,
      onTertiary: b.fondo,
      error: b.seguridad,
      onError: brillo == Brightness.dark ? const Color(0xFF2A0700) : Colors.white,
      errorContainer: b.seguridadSuave,
      onErrorContainer: b.texto,
      surface: b.hoja,
      onSurface: b.texto,
      onSurfaceVariant: b.textoSuave,
      surfaceContainerLowest: b.fondo,
      surfaceContainerLow: b.hoja,
      surfaceContainer: b.tarjeta,
      surfaceContainerHigh: b.campo,
      surfaceContainerHighest: b.campo,
      outline: b.asa,
      outlineVariant: b.divisor,
      inverseSurface: b.texto,
      onInverseSurface: b.fondo,
      inversePrimary: b.acento,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(colorScheme: esquema, useMaterial3: true, fontFamily: fuenteBahia);
    final t = base.textTheme;
    TextStyle? peso(TextStyle? estilo, FontWeight w, {double? tracking}) =>
        estilo?.copyWith(fontWeight: w, letterSpacing: tracking);
    final texto = t.copyWith(
      displaySmall: peso(t.displaySmall, FontWeight.w800, tracking: -0.5),
      headlineLarge: peso(t.headlineLarge, FontWeight.w800, tracking: -0.5),
      headlineMedium: peso(t.headlineMedium, FontWeight.w800, tracking: -0.3),
      headlineSmall: peso(t.headlineSmall, FontWeight.w800, tracking: -0.2),
      titleLarge: peso(t.titleLarge, FontWeight.w800),
      titleMedium: peso(t.titleMedium, FontWeight.w800),
      titleSmall: peso(t.titleSmall, FontWeight.w700),
      bodyLarge: peso(t.bodyLarge, FontWeight.w600),
      bodyMedium: peso(t.bodyMedium, FontWeight.w600),
      bodySmall: peso(t.bodySmall, FontWeight.w600),
      labelLarge: peso(t.labelLarge, FontWeight.w800),
      labelMedium: peso(t.labelMedium, FontWeight.w700),
      labelSmall: peso(t.labelSmall, FontWeight.w700),
    ).apply(bodyColor: b.texto, displayColor: b.texto);

    final redondeado = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    const alto = Size(64, 56);

    return base.copyWith(
      extensions: [b],
      scaffoldBackgroundColor: b.fondo,
      textTheme: texto,
      appBarTheme: AppBarTheme(
        backgroundColor: b.hoja,
        foregroundColor: b.texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: texto.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: alto, shape: redondeado, textStyle: texto.titleMedium),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: alto, shape: redondeado, side: BorderSide(color: b.asa, width: 1.5), textStyle: texto.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: b.acento, textStyle: texto.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: b.reportar,
        foregroundColor: b.sobreReportar,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b.campo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: b.acento, width: 2)),
        hintStyle: texto.bodyLarge?.copyWith(color: b.textoSuave),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: b.hoja,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: b.asa,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b.texto,
        contentTextStyle: texto.bodyMedium?.copyWith(color: b.fondo),
        actionTextColor: b.acento,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: b.hoja, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: b.divisor, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: b.acento,
        titleTextStyle: texto.bodyLarge,
        subtitleTextStyle: texto.bodyMedium?.copyWith(color: b.textoSuave),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: b.acento),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
    );
  }
}
