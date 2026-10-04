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
import 'ui/komponen.dart';
import 'ui/tokens.dart';

Future<void> _bagikanPdf(Uint8List pdf, String namaFile) async {
  await Printing.sharePdf(bytes: pdf, filename: namaFile);
}

const judulTabResmi = ['Posisi Keuangan', 'Laba Rugi', 'CaLK', 'Perubahan Ekuitas'];

class LaporanResmiPage extends StatefulWidget {
  const LaporanResmiPage({super.key, required this.data, this.bagikan});
  final DataLaporan data;
  final Future<void> Function(Uint8List pdf, String namaFile)? bagikan;

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
          Text('Pilih laporan', style: t.titleSmall),
          const SizedBox(height: 8),
          pilihan,
          const SizedBox(height: 20),
          ...isi,
        ],
      ),
    );
  }

  Widget _kepala(String judul, String periode) {
    final t = Theme.of(context).textTheme;
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.namaUsaha, style: t.titleMedium),
        Text(judul, style: t.titleLarge),
        Text(periode, style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        if (d.r.peringatanTinjau case final w?) ...[
          const SizedBox(height: 12),
          BannerPeringatan(judul: 'Perlu ditinjau', isi: w.pesan),
        ],
        if (!d.r.balanced) ...[
          const SizedBox(height: 12),
          BannerPeringatan(
            judul: 'Tidak seimbang',
            isi:
                'Total aset ${angkaResmi(d.r.totalAset)}, total liabilitas dan ekuitas '
                '${angkaResmi(d.r.totalLiabilitasEkuitas)}.',
            nada: Nada.error,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _laporan(LaporanResmi l) {
    final t = Theme.of(context).textTheme;
    return [
      _kepala(l.judul, l.keteranganPeriode),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in l.baris)
                switch (b.jenis) {
                  JenisBaris.judul => Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Semantics(header: true, child: Text(b.label, style: t.titleSmall)),
                  ),
                  JenisBaris.biasa => BarisLaporan(label: b.label, nilai: angkaResmi(b.nilai!), menjorok: b.menjorok),
                  JenisBaris.subtotal => Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Warna.teksSekunder)),
                    ),
                    child: BarisLaporan(label: b.label, nilai: angkaResmi(b.nilai!), tebal: true, menjorok: b.menjorok),
                  ),
                  JenisBaris.total => Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Warna.teks, width: 2),
                        bottom: BorderSide(color: Warna.teks, width: 2),
                      ),
                    ),
                    child: BarisLaporan(label: b.label, nilai: angkaResmi(b.nilai!), tebal: true),
                  ),
                },
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _calk() {
    final t = Theme.of(context).textTheme;
    final d = widget.data;
    return [
      _kepala('Catatan atas Laporan Keuangan', 'Untuk periode ${tanggalResmi(d.dari)} s.d. ${tanggalResmi(d.sampai)}'),
      for (final CalkSection s in d.calk)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text(s.judul, style: t.titleSmall)),
                  for (final p in s.paragraf)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(p, style: t.bodyLarge),
                    ),
                  for (final r in s.rincian) ...[
                    BarisLaporan(label: r.label, nilai: angkaResmi(r.nilai)),
                    if (r.keterangan != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(r.keterangan!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ];
  }
}
