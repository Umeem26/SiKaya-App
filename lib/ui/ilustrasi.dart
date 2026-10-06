// Ilustrasi datar onboarding, digambar dengan CustomPaint (tanpa aset gambar):
// bentuk sederhana berwarna merek di atas lingkaran biru muda. Hiasan saja;
// artinya selalu ada di judul dan kalimat di bawahnya.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

enum JenisIlustrasi { catat, untungAset, dataDiHp }

class Ilustrasi extends StatelessWidget {
  const Ilustrasi(this.jenis, {super.key, this.ukuran = 220});
  final JenisIlustrasi jenis;
  final double ukuran;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: ukuran,
          child: CustomPaint(
            painter: switch (jenis) {
              JenisIlustrasi.catat => _LukisCatat(),
              JenisIlustrasi.untungAset => _LukisUntungAset(),
              JenisIlustrasi.dataDiHp => _LukisDataDiHp(),
            },
          ),
        ),
      );
}

Paint _cat(Color c) => Paint()..color = c..isAntiAlias = true;

/// Latar bersama: lingkaran biru muda dan dua titik aksen.
void _latar(Canvas c, Size s) {
  final u = s.width;
  c.drawCircle(Offset(u / 2, u / 2), u * 0.48, _cat(Warna.primerMuda));
  c.drawCircle(Offset(u * 0.12, u * 0.22), u * 0.03, _cat(Warna.aksen));
  c.drawCircle(Offset(u * 0.9, u * 0.72), u * 0.022, _cat(Warna.primer));
}

RRect _kotak(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

/// Bayangan lembut di bawah benda (biru transparan, sama dengan bayangan kartu).
void _bayangan(Canvas c, RRect r) => c.drawRRect(r.shift(const Offset(0, 6)), _cat(Warna.bayangan));

/// Halaman 1: papan catatan berisi tiga baris kejadian (jual, pakan, upah) dan koin.
class _LukisCatat extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.width;
    _latar(c, s);
    // Papan catatan.
    final papan = _kotak(u * 0.24, u * 0.2, u * 0.5, u * 0.62, u * 0.06);
    _bayangan(c, papan);
    c.drawRRect(papan, _cat(Warna.permukaan));
    c.drawRRect(_kotak(u * 0.38, u * 0.15, u * 0.22, u * 0.1, u * 0.03), _cat(Warna.primer));
    // Tiga baris: ubin warna arah uang + garis tulisan.
    final warna = [Warna.sukses, Warna.aksen, Warna.primer];
    for (var i = 0; i < 3; i++) {
      final y = u * (0.33 + i * 0.15);
      c.drawRRect(_kotak(u * 0.3, y, u * 0.09, u * 0.09, u * 0.02), _cat(warna[i]));
      c.drawRRect(_kotak(u * 0.43, y + u * 0.012, u * 0.24, u * 0.025, u * 0.0125), _cat(Warna.garis));
      c.drawRRect(_kotak(u * 0.43, y + u * 0.053, u * 0.15, u * 0.022, u * 0.011), _cat(Warna.garis));
    }
    // Centang di baris pertama.
    final centang = Path()
      ..moveTo(u * 0.317, u * 0.375)
      ..lineTo(u * 0.34, u * 0.397)
      ..lineTo(u * 0.375, u * 0.355);
    c.drawPath(
        centang,
        _cat(Warna.putih)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.016
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    // Koin di pojok kanan bawah.
    final pusat = Offset(u * 0.72, u * 0.74);
    c.drawCircle(pusat.translate(0, 5), u * 0.11, _cat(Warna.bayangan));
    c.drawCircle(pusat, u * 0.11, _cat(Warna.aksen));
    c.drawCircle(pusat, u * 0.075, _cat(Warna.peringatanMuda));
    // Tulisan "Rp" di tengah koin (garis tegak saja terbaca sebagai tanda seru).
    final rp = TextPainter(
      text: TextSpan(
          text: 'Rp',
          style: TextStyle(color: Warna.aksenTeks, fontSize: u * 0.07, fontWeight: FontWeight.w900, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    rp.paint(c, pusat - Offset(rp.width / 2, rp.height / 2));
    rp.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Halaman 2: kandang, karung pakan, dan grafik batang yang naik.
class _LukisUntungAset extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.width;
    _latar(c, s);
    final tanah = u * 0.78;
    // Kandang: badan putih, atap biru, pintu oranye.
    final badan = _kotak(u * 0.14, u * 0.48, u * 0.4, tanah - u * 0.48, u * 0.02);
    _bayangan(c, badan);
    c.drawRRect(badan, _cat(Warna.permukaan));
    final atap = Path()
      ..moveTo(u * 0.1, u * 0.5)
      ..lineTo(u * 0.34, u * 0.3)
      ..lineTo(u * 0.58, u * 0.5)
      ..close();
    c.drawPath(atap, _cat(Warna.primer));
    c.drawRRect(_kotak(u * 0.28, u * 0.6, u * 0.12, tanah - u * 0.6, u * 0.015), _cat(Warna.aksen));
    c.drawCircle(Offset(u * 0.34, u * 0.42), u * 0.03, _cat(Warna.primerMuda));
    // Karung pakan di samping kandang.
    final karung = Path()
      ..moveTo(u * 0.56, tanah)
      ..quadraticBezierTo(u * 0.53, u * 0.64, u * 0.58, u * 0.6)
      ..lineTo(u * 0.66, u * 0.6)
      ..quadraticBezierTo(u * 0.71, u * 0.64, u * 0.68, tanah)
      ..close();
    c.drawPath(karung, _cat(Warna.aksen));
    c.drawRRect(_kotak(u * 0.585, u * 0.585, u * 0.07, u * 0.03, u * 0.01), _cat(Warna.peringatanMuda));
    // Grafik batang naik (untung) dengan panah.
    final tinggi = [0.12, 0.2, 0.3];
    for (var i = 0; i < 3; i++) {
      final x = u * (0.72 + i * 0.065);
      c.drawRRect(_kotak(x, tanah - u * tinggi[i], u * 0.05, u * tinggi[i], u * 0.012),
          _cat(i == 2 ? Warna.sukses : Warna.primerTerang));
    }
    final panah = _cat(Warna.sukses)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.018
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(u * 0.7, u * 0.5)
          ..lineTo(u * 0.79, u * 0.42)
          ..lineTo(u * 0.84, u * 0.45)
          ..lineTo(u * 0.92, u * 0.36),
        panah);
    c.drawPath(
        Path()
          ..moveTo(u * 0.87, u * 0.355)
          ..lineTo(u * 0.925, u * 0.355)
          ..lineTo(u * 0.925, u * 0.41),
        panah);
    // Garis tanah.
    c.drawRRect(_kotak(u * 0.1, tanah, u * 0.84, u * 0.02, u * 0.01), _cat(Warna.primer));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Halaman 3: HP berisi perisai bercentang (data aman), awan cadangan, tanpa sinyal.
class _LukisDataDiHp extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final u = s.width;
    _latar(c, s);
    // HP.
    final hp = _kotak(u * 0.3, u * 0.16, u * 0.38, u * 0.68, u * 0.06);
    _bayangan(c, hp);
    c.drawRRect(hp, _cat(Warna.teks));
    c.drawRRect(_kotak(u * 0.325, u * 0.22, u * 0.33, u * 0.54, u * 0.03), _cat(Warna.permukaan));
    c.drawRRect(_kotak(u * 0.44, u * 0.185, u * 0.1, u * 0.015, u * 0.0075), _cat(Warna.teksSekunder));
    // Perisai bercentang di layar.
    final p = Offset(u * 0.49, u * 0.44);
    final w = u * 0.2;
    final perisai = Path()
      ..moveTo(p.dx, p.dy - w * 0.62)
      ..lineTo(p.dx + w / 2, p.dy - w * 0.42)
      ..lineTo(p.dx + w / 2, p.dy)
      ..quadraticBezierTo(p.dx + w / 2, p.dy + w * 0.45, p.dx, p.dy + w * 0.65)
      ..quadraticBezierTo(p.dx - w / 2, p.dy + w * 0.45, p.dx - w / 2, p.dy)
      ..lineTo(p.dx - w / 2, p.dy - w * 0.42)
      ..close();
    c.drawPath(perisai, _cat(Warna.sukses));
    c.drawPath(
        Path()
          ..moveTo(p.dx - w * 0.22, p.dy)
          ..lineTo(p.dx - w * 0.04, p.dy + w * 0.18)
          ..lineTo(p.dx + w * 0.24, p.dy - w * 0.16),
        _cat(Warna.putih)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.022
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    // Dua baris tulisan di bawah perisai.
    c.drawRRect(_kotak(u * 0.37, u * 0.63, u * 0.24, u * 0.025, u * 0.0125), _cat(Warna.garis));
    c.drawRRect(_kotak(u * 0.4, u * 0.675, u * 0.18, u * 0.022, u * 0.011), _cat(Warna.garis));
    // Awan cadangan berpanah naik (kanan atas).
    final a = Offset(u * 0.8, u * 0.3);
    final awan = _cat(Warna.primer);
    c.drawCircle(a.translate(-u * 0.06, u * 0.02), u * 0.055, awan);
    c.drawCircle(a.translate(0, -u * 0.02), u * 0.07, awan);
    c.drawCircle(a.translate(u * 0.065, u * 0.02), u * 0.05, awan);
    c.drawRRect(_kotak(a.dx - u * 0.11, a.dy + u * 0.005, u * 0.22, u * 0.065, u * 0.03), awan);
    final panah = _cat(Warna.putih)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.016
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawLine(a.translate(0, u * 0.05), a.translate(0, -u * 0.035), panah);
    c.drawPath(
        Path()
          ..moveTo(a.dx - u * 0.035, a.dy)
          ..lineTo(a.dx, a.dy - u * 0.035)
          ..lineTo(a.dx + u * 0.035, a.dy),
        panah);
    // Sinyal dicoret (tanpa internet), kiri bawah.
    final g = Offset(u * 0.17, u * 0.66);
    final busur = _cat(Warna.aksenTeks)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.016
      ..strokeCap = StrokeCap.round;
    for (final r in [0.04, 0.075, 0.11]) {
      c.drawArc(Rect.fromCircle(center: g, radius: u * r), -math.pi * 0.75, math.pi / 2, false, busur);
    }
    c.drawCircle(g, u * 0.014, _cat(Warna.aksenTeks));
    c.drawLine(g.translate(-u * 0.1, -u * 0.11), g.translate(u * 0.1, u * 0.03), busur);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
