// Satu PDF berisi semua laporan resmi + CaLK (UI-PLAN.md 3.5), dari DataLaporan
// yang sama dengan layar. Huruf bawaan PDF (Helvetica) hanya mengenal Latin-1,
// jadi tanda yang tidak dikenal diganti dulu (lihat [teksPdf]).
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'accounting/calk.dart';
import 'laporan_data.dart';

/// Ganti karakter di luar Latin-1/WinAnsi agar bisa dicetak dengan huruf bawaan.
String teksPdf(String s) => s
    .replaceAll('−', '-') // minus
    .replaceAll('–', '-') // en dash
    .replaceAll('—', '-') // em dash
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ')
    .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

const _primer = PdfColor.fromInt(0xFF1E4FA3);
const _band = PdfColor.fromInt(0xFFEAF1FC);
const _teks = PdfColor.fromInt(0xFF1F2328);

String namaFilePdf(DataLaporan d) {
  String iso(DateTime t) => t.toIso8601String().substring(0, 10);
  return 'laporan_keuangan_${iso(d.dari)}_${iso(d.sampai)}.pdf';
}

Future<Uint8List> buatPdfLaporan(DataLaporan d, {bool kompres = true}) {
  final doc = pw.Document(
    compress: kompres,
    title: teksPdf('Laporan Keuangan ${d.namaUsaha}'),
    author: 'SiKaya',
  );
  pw.Widget t(String s, {double size = 11, bool tebal = false, PdfColor? warna}) => pw.Text(teksPdf(s),
      style: pw.TextStyle(
          fontSize: size, fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal, color: warna));

  // Kop (gaya laporan lama): kotak bergaris, rata tengah, nama usaha - judul - periode.
  pw.Widget kepala(String judul, String periode) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const pw.EdgeInsets.only(bottom: 14),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2, color: _teks)),
        child: pw.Column(children: [
          t(d.namaUsaha, size: 13, tebal: true),
          pw.SizedBox(height: 2),
          t(judul, size: 15, tebal: true, warna: _primer),
          pw.SizedBox(height: 2),
          t(periode, size: 10),
        ]),
      );

  // Band judul seksi: latar biru muda, tulisan biru tebal.
  pw.Widget band(String label) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _band,
        child: t(label, tebal: true, warna: _primer),
      );

  pw.Widget baris(String label, String? nilai, {bool tebal = false, int menjorok = 0, bool garis = false}) =>
      pw.Container(
        padding: pw.EdgeInsets.only(left: 8 + 14.0 * menjorok, right: 8, top: 3, bottom: 3),
        decoration: garis ? const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.7))) : null,
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: t(label, tebal: tebal)),
          if (nilai != null) pw.SizedBox(width: 12),
          if (nilai != null) pw.Text(teksPdf(nilai), textAlign: pw.TextAlign.right, style: pw.TextStyle(
              fontSize: 11, fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );

  // Total: garis tunggal di atas, garis ganda di bawah (konvensi akuntansi).
  pw.Widget total(String label, String nilai) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Column(children: [
          pw.Container(height: 0.9, color: _teks),
          baris(label, nilai, tebal: true),
          pw.Container(height: 0.9, color: _teks),
          pw.SizedBox(height: 1.6),
          pw.Container(height: 0.9, color: _teks),
        ]),
      );

  List<pw.Widget> laporan(LaporanResmi l) => [
        kepala(l.judul, l.keteranganPeriode),
        for (final b in l.baris)
          switch (b.jenis) {
            JenisBaris.judul => band(b.label),
            JenisBaris.biasa => baris(b.label, angkaResmi(b.nilai!), menjorok: b.menjorok),
            JenisBaris.subtotal => baris(b.label, angkaResmi(b.nilai!), tebal: true, menjorok: b.menjorok, garis: true),
            JenisBaris.total => total(b.label, angkaResmi(b.nilai!)),
          },
      ];

  List<pw.Widget> calk(List<CalkSection> s) => [
        kepala('Catatan atas Laporan Keuangan', 'Untuk periode ${tanggalResmi(d.dari)} s.d. ${tanggalResmi(d.sampai)}'),
        for (final x in s) ...[
          band(x.judul),
          for (final p in x.paragraf)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 14, bottom: 4),
              child: pw.Text(teksPdf(p), textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 11)),
            ),
          for (final r in x.rincian) ...[
            baris(r.label, angkaResmi(r.nilai), menjorok: 1),
            if (r.keterangan != null)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 28, bottom: 2),
                  child: t(r.keterangan!, size: 9, warna: PdfColors.grey800)),
          ],
        ],
      ];

  final peringatan = [
    if (d.r.peringatanTinjau case final w?) w.pesan,
    if (!d.r.balanced) 'Laporan Posisi Keuangan tidak seimbang.',
  ];

  final halaman = [
    [
      if (peringatan.isNotEmpty)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final p in peringatan) t('Perhatian: $p', tebal: true)]),
        ),
      ...laporan(d.posisiKeuangan),
    ],
    laporan(d.labaRugi),
    calk(d.calk),
    laporan(d.perubahanEkuitas),
  ];

  for (final isi in halaman) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: t('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}', size: 9, warna: PdfColors.grey800),
      ),
      build: (_) => isi,
    ));
  }
  return doc.save();
}
