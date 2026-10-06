// Tema terang SiKaya (UI-PLAN.md bagian 1-2). Ukuran huruf hanya di sini dan
// selalu dikalikan pengaturan font HP (textScaler tidak dikunci).
// Bahasa visual mengikuti UI lama (docs/engineering/UI-LAMA-NOTES.md): app bar biru bersudut
// bawah membulat, kartu putih tanpa garis tepi dengan bayangan biru tipis, tombol
// kedua berisi biru muda (bukan garis tepi), sudut kartu/tombol 16.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Bilah sistem di aplikasi: status bar transparan berikon putih (di atas biru merek),
/// bilah navigasi putih berikon gelap (di bawah navigasi bawah yang putih). Splash
/// memakai bilah navigasi biru sendiri.
const gayaSistem = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Warna.permukaan,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Warna.garis,
);

/// Tinggi sentuh minimum (dp) untuk semua kontrol; tombol utama memakai [tinggiTombolUtama].
const double tinggiSentuh = 48;
const double tinggiTombolUtama = 56;

/// Angka uang: figur tabular agar digit sejajar antarbaris.
const angkaTabular = [FontFeature.tabularFigures()];

/// [gaya] dengan figur tabular (nominal Rupiah, jumlah).
TextStyle gayaAngka(TextStyle gaya) => gaya.copyWith(fontFeatures: angkaTabular);

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
    outline: Warna.tepiIsian,
    outlineVariant: Warna.garis,
    surfaceTint: Colors.transparent,
    shadow: Warna.bayangan,
  );

  // Huruf dasar 18sp (Text tanpa gaya memakai bodyMedium). Hirarki lewat ukuran
  // DAN ketebalan: judul layar 22/w800, judul seksi 20/w700, judul kartu 18/w600.
  const teks = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.2),
    headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.2),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
    titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
    titleSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
    bodyLarge: TextStyle(fontSize: 18, height: 1.4),
    bodyMedium: TextStyle(fontSize: 18, height: 1.4),
    bodySmall: TextStyle(fontSize: 16, height: 1.4),
    labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  final bentuk = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sudut.kartu));
  final tombol = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(tinggiSentuh, tinggiSentuh)),
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: WidgetStatePropertyAll(bentuk),
    textStyle: WidgetStatePropertyAll(teks.labelLarge),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    iconSize: const WidgetStatePropertyAll(24),
  );
  final tepi = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Sudut.kecil),
    borderSide: const BorderSide(color: Warna.tepiIsian),
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
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Warna.bayangan,
      centerTitle: false,
      titleSpacing: Jarak.s16,
      toolbarHeight: 64,
      titleTextStyle: teks.titleLarge!.copyWith(color: Warna.putih),
      systemOverlayStyle: gayaSistem,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: tombol.copyWith(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Warna.garis : null),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Warna.teksSekunder : null),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: tombol),
    // Tombol kedua: berisi biru muda tanpa garis tepi (primer di atas primerMuda 6,84:1).
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tombol.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Warna.garis : Warna.primerMuda),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Warna.teksSekunder : Warna.primer),
        side: const WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: tombol),
    cardTheme: CardThemeData(
      color: Warna.permukaan,
      surfaceTintColor: Colors.transparent,
      shadowColor: Warna.bayangan,
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sudut.kartu)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Warna.permukaan,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: teks.titleLarge!.copyWith(color: Warna.teks),
      contentTextStyle: teks.bodyLarge!.copyWith(color: Warna.teks),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.permukaan,
      border: tepi,
      enabledBorder: tepi,
      focusedBorder: tepi.copyWith(borderSide: const BorderSide(color: Warna.primer, width: 2)),
      errorBorder: tepi.copyWith(borderSide: const BorderSide(color: Warna.error, width: 2)),
      focusedErrorBorder: tepi.copyWith(borderSide: const BorderSide(color: Warna.error, width: 2)),
      labelStyle: teks.bodyLarge!.copyWith(color: Warna.teksSekunder),
      hintStyle: teks.bodyLarge!.copyWith(color: Warna.teksSekunder),
      helperStyle: teks.bodySmall!.copyWith(color: Warna.teksSekunder),
      errorStyle: teks.bodySmall!.copyWith(color: Warna.error),
      prefixIconColor: Warna.primer,
      contentPadding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s16),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Warna.tepiIsian, width: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Warna.teks,
      contentTextStyle: teks.bodyLarge!.copyWith(color: Warna.putih),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sudut.kecil)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Warna.primer),
    dividerTheme: const DividerThemeData(color: Warna.garis, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: Warna.primer),
  );
}

/// Isian terisi bersudut bulat untuk form di dalam kartu (form Catat): latar
/// [Warna.isian] tanpa garis tepi; garis 2dp hanya saat difokus atau salah.
/// Label selalu di atas isian ([LabelIsian]), jadi kotak tidak perlu garis untuk dikenali.
ThemeData temaIsianTerisi(ThemeData dasar) {
  final bulat = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Sudut.kecil),
    borderSide: BorderSide.none,
  );
  return dasar.copyWith(
    inputDecorationTheme: dasar.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Warna.isian,
      border: bulat,
      enabledBorder: bulat,
      disabledBorder: bulat,
      focusedBorder: bulat.copyWith(borderSide: const BorderSide(color: Warna.primer, width: 2)),
      errorBorder: bulat.copyWith(borderSide: const BorderSide(color: Warna.error, width: 2)),
      focusedErrorBorder: bulat.copyWith(borderSide: const BorderSide(color: Warna.error, width: 2)),
    ),
  );
}

/// true bila isian di [context] memakai [temaIsianTerisi] (baris pilihan ikut terisi).
bool isianTerisi(BuildContext context) =>
    Theme.of(context).inputDecorationTheme.enabledBorder?.borderSide.style == BorderStyle.none;
