// Inventaris: daftar barang per kelompok (UI-PLAN.md 3.6). Pilihan kelompok berupa
// tombol yang semuanya terlihat; ketuk barang untuk detail (Ubah/Hapus).
import 'dart:io';

import 'package:flutter/material.dart';

import 'asset_model.dart';
import 'detail_asset_page.dart';
import 'form_asset_page.dart';
import 'inventaris_data.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class ListAssetPage extends StatefulWidget {
  const ListAssetPage({super.key, this.sumber});
  final SumberInventaris? sumber;

  @override
  State<ListAssetPage> createState() => _ListAssetPageState();
}

class _ListAssetPageState extends State<ListAssetPage> {
  late final SumberInventaris _sumber = widget.sumber ?? SumberInventaris.instance;
  late Future<List<AssetModel>> _data = _sumber.semua();
  String _kelompok = kelompokInventaris.first.nilai;

  void _muatUlang() {
    setState(() {
      _data = _sumber.semua();
    });
  }

  Future<void> _buka(Widget halaman) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => halaman));
    if (mounted) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaris')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(
            label: 'Tambah barang',
            ikon: Icons.add_rounded,
            onPressed: () => _buka(FormAssetPage(sumber: widget.sumber, kelompokAwal: _kelompok)),
          ),
        ),
      ),
      body: FutureBuilder<List<AssetModel>>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              BannerPeringatan(
                judul: 'Inventaris tidak bisa dibaca',
                isi: '${snap.error}',
                nada: Nada.error,
                aksi: 'Coba lagi',
                ikonAksi: Icons.refresh_rounded,
                onAksi: _muatUlang,
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return _daftar(snap.data!);
        },
      ),
    );
  }

  Widget _daftar(List<AssetModel> semua) {
    final t = Theme.of(context).textTheme;
    final barang = semua.where((a) => a.kategori == _kelompok).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('Catatan barang yang dimiliki. Tidak masuk laporan keuangan; untuk mencatat pembelian '
            'pakai "Apa yang terjadi?".',
            style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in kelompokInventaris)
            TombolPilihan(
              label: '${k.label} (${semua.where((a) => a.kategori == k.nilai).length})',
              terpilih: k.nilai == _kelompok,
              onPressed: () => setState(() => _kelompok = k.nilai),
            ),
        ]),
        const SizedBox(height: 16),
        if (barang.isEmpty)
          Text('Belum ada barang di kelompok ini. Tekan "Tambah barang" di bawah.', style: t.bodyLarge),
        for (final a in barang) ...[
          ItemInventaris(barang: a, onTap: () => _buka(DetailAssetPage(asset: a, sumber: widget.sumber))),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Satu baris barang: nama, jumlah + satuan, kondisi (kata + ikon), foto bila ada.
class ItemInventaris extends StatelessWidget {
  const ItemInventaris({super.key, required this.barang, this.onTap});
  final AssetModel barang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = barang;
    final baik = a.kondisi == 'Baik';
    final foto = a.imagePath.isNotEmpty && File(a.imagePath).existsSync();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (foto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(a.imagePath), width: 56, height: 56, fit: BoxFit.cover),
                )
              else
                const Icon(Icons.inventory_2_rounded, color: Warna.primer, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.nama, style: t.titleSmall),
                  Text('${a.jumlah} ${a.satuan ?? ''}'.trim(), style: t.bodyLarge),
                  Row(children: [
                    Icon(baik ? Icons.check_circle_rounded : Icons.build_rounded,
                        color: baik ? Warna.sukses : Warna.peringatan, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Kondisi: ${a.kondisi}',
                          style: t.bodySmall!.copyWith(color: baik ? Warna.sukses : Warna.peringatan)),
                    ),
                  ]),
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Warna.teksSekunder),
            ]),
          ),
        ),
      ),
    );
  }
}
