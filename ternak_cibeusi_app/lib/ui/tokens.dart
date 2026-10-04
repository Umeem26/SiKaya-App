// Token warna SiKaya (UI-PLAN.md bagian 2). Diturunkan dari logo
// assets/icon_ayam.png: biru panah dan oranye koin, digelapkan agar teks
// kontras minimal 4,5:1 di layar luar ruangan. Tema terang saja.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract final class Warna {
  static const primer = Color(0xFF1E4FA3);
  static const primerMuda = Color(0xFFEAF1FC);

  /// Isian/ikon saja. Teks di atasnya harus [teks] (putih hanya 2,36:1).
  static const aksen = Color(0xFFE4993A);
  static const aksenTeks = Color(0xFF9A4F00);
  static const latar = Color(0xFFFFFBF5);
  static const permukaan = Color(0xFFFFFFFF);
  static const teks = Color(0xFF1F2328);
  static const teksSekunder = Color(0xFF4B5563);
  static const sukses = Color(0xFF1B6B3A);
  static const suksesMuda = Color(0xFFE7F4EC);
  static const peringatan = Color(0xFF8A4B00);
  static const peringatanMuda = Color(0xFFFFF1D6);
  static const error = Color(0xFFB3261E);
  static const errorMuda = Color(0xFFFDECEA);
  static const putih = Color(0xFFFFFFFF);
}

/// Pasangan teks/latar yang dipakai UI. Setiap pasangan wajib >= 4,5:1
/// (diuji di test/ui/kontras_test.dart). Tambahkan di sini bila memakai pasangan baru.
const pasanganKontras = <(String, Color, Color)>[
  ('putih di atas primer', Warna.putih, Warna.primer),
  ('primer di atas latar', Warna.primer, Warna.latar),
  ('primer di atas permukaan', Warna.primer, Warna.permukaan),
  ('primer di atas primerMuda', Warna.primer, Warna.primerMuda),
  ('teks di atas aksen', Warna.teks, Warna.aksen),
  ('aksenTeks di atas latar', Warna.aksenTeks, Warna.latar),
  ('aksenTeks di atas permukaan', Warna.aksenTeks, Warna.permukaan),
  ('putih di atas aksenTeks', Warna.putih, Warna.aksenTeks),
  ('teks di atas latar', Warna.teks, Warna.latar),
  ('teks di atas permukaan', Warna.teks, Warna.permukaan),
  ('teks di atas primerMuda', Warna.teks, Warna.primerMuda),
  ('teksSekunder di atas primerMuda (pilihan terpilih)', Warna.teksSekunder, Warna.primerMuda),
  ('teksSekunder di atas latar', Warna.teksSekunder, Warna.latar),
  ('teksSekunder di atas permukaan', Warna.teksSekunder, Warna.permukaan),
  ('sukses di atas latar', Warna.sukses, Warna.latar),
  ('sukses di atas permukaan', Warna.sukses, Warna.permukaan),
  ('sukses di atas suksesMuda', Warna.sukses, Warna.suksesMuda),
  ('putih di atas sukses', Warna.putih, Warna.sukses),
  ('peringatan di atas peringatanMuda', Warna.peringatan, Warna.peringatanMuda),
  ('peringatan di atas latar', Warna.peringatan, Warna.latar),
  ('teks di atas peringatanMuda', Warna.teks, Warna.peringatanMuda),
  ('error di atas latar', Warna.error, Warna.latar),
  ('error di atas permukaan', Warna.error, Warna.permukaan),
  ('error di atas errorMuda', Warna.error, Warna.errorMuda),
  ('teks di atas errorMuda', Warna.teks, Warna.errorMuda),
  ('putih di atas error', Warna.putih, Warna.error),
  ('putih di atas teks (snackbar)', Warna.putih, Warna.teks),
];

/// Luminans relatif WCAG 2.x.
double luminans(Color c) {
  double kanal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

/// Rasio kontras WCAG 2.x (1..21).
double rasioKontras(Color a, Color b) {
  final la = luminans(a), lb = luminans(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
