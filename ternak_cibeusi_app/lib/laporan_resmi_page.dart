// Laporan lapis 2: laporan resmi SAK EMKM (UI-PLAN.md 3.5). Pilihan Posisi
// Keuangan, Laba Rugi, CaLK, Perubahan Ekuitas berupa tombol yang semuanya
// terlihat (bukan tab yang harus digeser); "Ekspor PDF" membuat satu file berisi
// semuanya lalu membuka lembar bagikan. Data = DataLaporan yang sama dengan Ringkasan.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'accounting/calk.dart';
import 'laporan_data.dart';
import 'laporan_pdf.dart';
import 'ui/alasan.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

Future<void> _bagikanPdf(Uint8List pdf, String namaFile) async {
  await Printing.sharePdf(bytes: pdf, filename: namaFile);
}

const judulTabResmi = ['Posisi Keuangan', 'Laba Rugi', 'CaLK', 'Perubahan Ekuitas'];

class LaporanResmiPage extends StatefulWidget {
  const LaporanResmiPage({super.key, required this.data, this.bagikan, this.ditutupSampai});
  final DataLaporan data;
  final Future<void> Function(Uint8List pdf, String namaFile)? bagikan;

  /// Tanggal tutup buku terakhir; periode yang mencakupnya berlencana "Ditutup".
  final DateTime? ditutupSampai;

  @override
  State<LaporanResmiPage> createState() => _LaporanResmiPageState();
}

class _LaporanResmiPageState extends State<LaporanResmiPage> {
  bool _membuat = false;
  int _tab = 0;

  Future<void> _ekspor() async {
    setState(() => _membuat = true);
    try {
      final pdf = await buatPdfLaporan(widget.data);
      await (widget.bagikan ?? _bagikanPdf)(pdf, namaFilePdf(widget.data));
    } catch (e) {
      if (mounted) await tampilkanPesan(context, judul: 'PDF gagal dibuat', isi: '$e', gagal: true);
    } finally {
      if (mounted) setState(() => _membuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final t = Theme.of(context).textTheme;
    final pilihan = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < judulTabResmi.length; i++)
          TombolPilihan(
            label: judulTabResmi[i],
            terpilih: i == _tab,
            ikon: Icons.description_rounded,
            onPressed: () => setState(() => _tab = i),
          ),
      ],
    );
    final isi = switch (_tab) {
      0 => _laporan(d.posisiKeuangan),
      1 => _laporan(d.labaRugi),
      2 => _calk(),
      _ => _laporan(d.perubahanEkuitas),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan resmi')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(
            label: _membuat ? 'Membuat PDF...' : 'Ekspor PDF',
            ikon: Icons.picture_as_pdf_rounded,
            onPressed: _membuat ? null : _ekspor,
          ),
        ),
      ),
      // Kunci per laporan: ganti laporan = mulai dari atas.
      body: ListView(
        key: ValueKey(_tab),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Pilih laporan', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Jarak.s8),
          pilihan,
          const SizedBox(height: Jarak.s16),
          ...isi,
        ],
      ),
    );
  }

  /// Kop laporan (gaya laporan lama): kotak bergaris, rata tengah.
  Widget _kepala(String judul, String periode) {
    final t = Theme.of(context).textTheme;
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s12),
          decoration: BoxDecoration(
            border: Border.all(color: Warna.teks, width: 1.5),
            borderRadius: BorderRadius.circular(Sudut.kecil),
          ),
          child: Column(children: [
            Text(d.namaUsaha, textAlign: TextAlign.center, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Jarak.s4),
            Semantics(
              header: true,
              child: Text(judul, textAlign: TextAlign.center, style: t.titleLarge!.copyWith(color: Warna.primer)),
            ),
            const SizedBox(height: Jarak.s4),
            Text(periode, textAlign: TextAlign.center, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
            if (widget.ditutupSampai case final k? when !d.dari.isAfter(k))
              LencanaDitutup(label: labelDitutup(k), onTap: () => jelaskanDitutup(context, k)),
          ]),
        ),
        if (d.r.peringatanTinjau case final w?) ...[
          const SizedBox(height: Jarak.s12),
          BannerPeringatan(judul: 'Perlu ditinjau', isi: w.pesan),
        ],
        if (!d.r.balanced) ...[
          const SizedBox(height: Jarak.s12),
          BannerPeringatan(
            judul: 'Tidak seimbang',
            isi:
                'Total aset ${angkaResmi(d.r.totalAset)}, total liabilitas dan ekuitas '
                '${angkaResmi(d.r.totalLiabilitasEkuitas)}.',
            nada: Nada.error,
          ),
        ],
        const SizedBox(height: Jarak.s8),
      ],
    );
  }

  /// Kertas laporan: putih, bersudut, berbayang tipis.
  Widget _kertas(List<Widget> isi) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, Jarak.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: isi),
        ),
      );

  List<Widget> _laporan(LaporanResmi l) => [
        _kertas([
          _kepala(l.judul, l.keteranganPeriode),
          for (final b in l.baris)
            switch (b.jenis) {
              JenisBaris.judul => BandJudul(b.label),
              JenisBaris.biasa => BarisLaporan(label: b.label, nilai: angkaResmi(b.nilai!), menjorok: b.menjorok),
              JenisBaris.subtotal => Container(
                  margin: const EdgeInsets.only(top: Jarak.s4),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.teksSekunder))),
                  child: BarisLaporan(label: b.label, nilai: angkaResmi(b.nilai!), tebal: true, menjorok: b.menjorok),
                ),
              JenisBaris.total => BarisTotal(label: b.label, nilai: angkaResmi(b.nilai!)),
            },
        ]),
      ];

  List<Widget> _calk() {
    final t = Theme.of(context).textTheme;
    final d = widget.data;
    return [
      _kertas([
        _kepala('Catatan atas Laporan Keuangan', 'Untuk periode ${tanggalResmi(d.dari)} s.d. ${tanggalResmi(d.sampai)}'),
        for (final CalkSection s in d.calk) ...[
          BandJudul(s.judul),
          for (final p in s.paragraf)
            Padding(
              padding: const EdgeInsets.only(top: Jarak.s8, left: Jarak.s8),
              child: Text(p, style: t.bodyLarge),
            ),
          for (final r in s.rincian) ...[
            BarisLaporan(label: r.label, nilai: angkaResmi(r.nilai), menjorok: 1),
            if (r.keterangan != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Jarak.s4, left: Jarak.s24),
                child: Text(r.keterangan!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
              ),
          ],
          const SizedBox(height: Jarak.s8),
        ],
      ]),
    ];
  }
}

/// Band judul seksi laporan (ASET, LIABILITAS, ...): latar biru muda, tulisan biru tebal.
class BandJudul extends StatelessWidget {
  const BandJudul(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: Jarak.s12, bottom: Jarak.s4),
        padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s8),
        decoration: BoxDecoration(color: Warna.primerMuda, borderRadius: BorderRadius.circular(8)),
        child: Semantics(
          header: true,
          child: Text(label,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Warna.primer, fontWeight: FontWeight.w800)),
        ),
      );
}

/// Baris total: garis tunggal di atas, garis ganda di bawah (konvensi akuntansi).
class BarisTotal extends StatelessWidget {
  const BarisTotal({super.key, required this.label, required this.nilai});
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Jarak.s8, bottom: Jarak.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Divider(color: Warna.teks, thickness: 1.5, height: 1.5),
          BarisLaporan(label: label, nilai: nilai, tebal: true),
          const Divider(color: Warna.teks, thickness: 1.5, height: 1.5),
          const SizedBox(height: 2.5),
          const Divider(color: Warna.teks, thickness: 1.5, height: 1.5),
        ]),
      );
}
