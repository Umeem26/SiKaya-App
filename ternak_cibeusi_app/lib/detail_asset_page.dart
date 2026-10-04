// Inventaris: detail satu barang dengan tombol "Ubah" dan "Hapus" berlabel.
import 'dart:io';

import 'package:flutter/material.dart';

import 'asset_model.dart';
import 'form_asset_page.dart';
import 'inventaris_data.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class DetailAssetPage extends StatefulWidget {
  const DetailAssetPage({super.key, required this.asset, this.sumber});
  final AssetModel asset;
  final SumberInventaris? sumber;

  @override
  State<DetailAssetPage> createState() => _DetailAssetPageState();
}

class _DetailAssetPageState extends State<DetailAssetPage> {
  late final SumberInventaris _sumber = widget.sumber ?? SumberInventaris.instance;
  late AssetModel _a = widget.asset;

  Future<void> _ubah() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => FormAssetPage(asset: _a, sumber: widget.sumber)));
    final baru = _a.id == null ? null : await _sumber.byId(_a.id!);
    if (!mounted) return;
    if (baru == null) {
      Navigator.pop(context);
    } else {
      setState(() => _a = baru);
    }
  }

  Future<void> _hapus() async {
    final ya = await tanyaKonfirmasi(
      context,
      judul: 'Hapus barang ini?',
      isi: '${_a.nama} (${_a.jumlah} ${_a.satuan ?? ''}) dihapus dari daftar inventaris. '
          'Laporan keuangan tidak berubah.',
      aksi: 'Hapus',
      ikonAksi: Icons.delete,
      bahaya: true,
    );
    if (!ya || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _sumber.hapus(_a.id!);
    messenger.showSnackBar(const SnackBar(content: Text('Barang dihapus dari inventaris.')));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = _a;
    final foto = a.imagePath.isNotEmpty && File(a.imagePath).existsSync();
    final baris = <(String, String)>[
      ('Kelompok', kelompokDari(a.kategori).label),
      ('Jumlah', '${a.jumlah} ${a.satuan ?? ''}'.trim()),
      ('Kondisi', a.kondisi),
      ('Tanggal dicatat', tanggalPanjang(a.date)),
      if (a.statusKepemilikan case final s?) ('Status kepemilikan', s),
      if (a.fungsiLahan case final f? when f.isNotEmpty) ('Fungsi lahan', f),
      ('Keterangan', a.deskripsi.isEmpty ? '-' : a.deskripsi),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Detail barang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (foto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(a.imagePath), height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          Text(a.nama, style: t.headlineSmall),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (final (label, isi) in baris) BarisLaporan(label: label, nilai: isi),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text('Inventaris tidak masuk laporan keuangan.', style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
          const SizedBox(height: 24),
          TombolKedua(label: 'Ubah', ikon: Icons.edit, onPressed: _ubah),
          const SizedBox(height: 12),
          TombolBahaya(label: 'Hapus', ikon: Icons.delete, onPressed: _hapus),
        ],
      ),
    );
  }
}
