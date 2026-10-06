// Token warna SiKaya (UI-PLAN.md bagian 2). Diturunkan dari logo
// assets/icon_ayam.png: biru panah dan oranye koin, digelapkan agar teks
// kontras minimal 4,5:1 di layar luar ruangan. Tema terang saja.
// Nuansa mengikuti UI lama (docs/ref-lama): latar biru-abu sejuk, header dan
// kartu utama bergradien biru, kartu putih berbayang tipis tanpa garis tepi.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract final class Warna {
  static const primer = Color(0xFF1E4FA3);
  static const primerMuda = Color(0xFFEAF1FC);

  /// Ujung terang dan gelap gradien merek (header Beranda, kartu utama). Teks putih.
  static const primerTerang = Color(0xFF2A62C2);
  static const primerGelap = Color(0xFF163B7A);

  /// Teks sekunder di atas biru merek (pengganti white70 yang samar).
  static const primerPudar = Color(0xFFD6E4FA);

  /// Isian/ikon saja. Teks di atasnya harus [teks] (putih hanya 2,36:1).
  static const aksen = Color(0xFFE4993A);
  static const aksenTeks = Color(0xFF9A4F00);
  static const latar = Color(0xFFF3F6FB);
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

  /// Garis pemisah tipis (bukan penanda arti; tidak perlu 3:1).
  static const garis = Color(0xFFE1E6EF);

  /// Latar isian terisi (form Catat) di atas kartu putih; teks di atasnya [teks]/[teksSekunder].
  static const isian = Color(0xFFEDF1F8);

  /// Tepi kotak isian: >= 3:1 di atas permukaan (WCAG 1.4.11).
  static const tepiIsian = Color(0xFF7B8494);

  /// Bayangan kartu: biru merek transparan, lembut seperti UI lama.
  static const bayangan = Color(0x261E4FA3);
}

/// Skala jarak 4/8/12/16/24 dp. Semua padding/jarak antar-elemen memakai ini.
abstract final class Jarak {
  static const double s4 = 4, s8 = 8, s12 = 12, s16 = 16, s24 = 24;
}

/// Sudut: kartu dan tombol 16, elemen kecil (ubin ikon, isian, chip) 12.
abstract final class Sudut {
  static const double kartu = 16, kecil = 12;
}

/// Gradien merek (atas-kiri terang ke bawah-kanan gelap).
const gradienMerek = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Warna.primerTerang, Warna.primer, Warna.primerGelap],
  stops: [0, 0.55, 1],
);

/// Bayangan kartu putih (tipis) dan kartu merek (lebih dalam, seperti UI lama).
const bayanganKartu = [BoxShadow(color: Warna.bayangan, blurRadius: 12, offset: Offset(0, 4))];
const bayanganMerek = [BoxShadow(color: Color(0x401E4FA3), blurRadius: 20, offset: Offset(0, 8))];

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
  ('peringatan di atas permukaan (kartu utang)', Warna.peringatan, Warna.permukaan),
  ('teks di atas peringatanMuda', Warna.teks, Warna.peringatanMuda),
  ('error di atas latar', Warna.error, Warna.latar),
  ('error di atas permukaan', Warna.error, Warna.permukaan),
  ('error di atas errorMuda', Warna.error, Warna.errorMuda),
  ('teks di atas errorMuda', Warna.teks, Warna.errorMuda),
  ('putih di atas error', Warna.putih, Warna.error),
  ('putih di atas teks (snackbar)', Warna.putih, Warna.teks),
  // Gradien merek: teks putih dan primerPudar harus lolos di ujung yang paling terang.
  ('putih di atas primerTerang (gradien)', Warna.putih, Warna.primerTerang),
  ('putih di atas primerGelap (gradien)', Warna.putih, Warna.primerGelap),
  ('primerPudar di atas primerTerang', Warna.primerPudar, Warna.primerTerang),
  ('primerPudar di atas primer', Warna.primerPudar, Warna.primer),
  ('primerPudar di atas primerGelap', Warna.primerPudar, Warna.primerGelap),
  ('sukses di atas suksesMuda (chip Untung)', Warna.sukses, Warna.suksesMuda),
  ('aksenTeks di atas peringatanMuda (chip stok)', Warna.aksenTeks, Warna.peringatanMuda),
  // Isian terisi form Catat: isi, awalan/satuan, ikon, dan pesan salah di atas latar isian.
  ('teks di atas isian', Warna.teks, Warna.isian),
  ('teksSekunder di atas isian', Warna.teksSekunder, Warna.isian),
  ('primer di atas isian', Warna.primer, Warna.isian),
  ('error di atas isian', Warna.error, Warna.isian),
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
