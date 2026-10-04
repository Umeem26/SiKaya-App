// Tema terang SiKaya (UI-PLAN.md bagian 1-2). Ukuran huruf hanya di sini dan
// selalu dikalikan pengaturan font HP (textScaler tidak dikunci).
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tinggi sentuh minimum (dp) untuk semua kontrol; tombol utama memakai [tinggiTombolUtama].
const double tinggiSentuh = 48;
const double tinggiTombolUtama = 56;

ThemeData temaSikaya() {
  const skema = ColorScheme(
    brightness: Brightness.light,
    primary: Warna.primer,
    onPrimary: Warna.putih,
    primaryContainer: Warna.primerMuda,
    onPrimaryContainer: Warna.primer,
    secondary: Warna.aksen,
    onSecondary: Warna.teks,
    tertiary: Warna.sukses,
    onTertiary: Warna.putih,
    error: Warna.error,
    onError: Warna.putih,
    errorContainer: Warna.errorMuda,
    onErrorContainer: Warna.error,
    surface: Warna.permukaan,
    onSurface: Warna.teks,
    onSurfaceVariant: Warna.teksSekunder,
    outline: Warna.teksSekunder,
  );

  // Huruf dasar 18sp (Text tanpa gaya memakai bodyMedium).
  const teks = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
    headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
    titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
    bodyLarge: TextStyle(fontSize: 18, height: 1.4),
    bodyMedium: TextStyle(fontSize: 18, height: 1.4),
    bodySmall: TextStyle(fontSize: 16, height: 1.4),
    labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  final bentuk = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final tombol = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(tinggiSentuh, tinggiSentuh)),
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: WidgetStatePropertyAll(bentuk),
    textStyle: WidgetStatePropertyAll(teks.labelLarge),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: skema,
    scaffoldBackgroundColor: Warna.latar,
    textTheme: teks.apply(bodyColor: Warna.teks, displayColor: Warna.teks),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: Warna.primer,
      foregroundColor: Warna.putih,
      centerTitle: false,
      titleTextStyle: teks.titleLarge!.copyWith(color: Warna.putih),
    ),
    filledButtonTheme: FilledButtonThemeData(style: tombol),
    elevatedButtonTheme: ElevatedButtonThemeData(style: tombol),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tombol.copyWith(
        side: const WidgetStatePropertyAll(BorderSide(color: Warna.primer, width: 2)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: tombol),
    cardTheme: CardThemeData(
      color: Warna.permukaan,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E1DA)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Warna.permukaan,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: teks.titleLarge!.copyWith(color: Warna.teks),
      contentTextStyle: teks.bodyLarge!.copyWith(color: Warna.teks),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.permukaan,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: teks.bodyLarge!.copyWith(color: Warna.teksSekunder),
      helperStyle: teks.bodySmall!.copyWith(color: Warna.teksSekunder),
      errorStyle: teks.bodySmall!.copyWith(color: Warna.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Warna.teks,
      contentTextStyle: teks.bodyLarge!.copyWith(color: Warna.putih),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE5E1DA)),
  );
}
