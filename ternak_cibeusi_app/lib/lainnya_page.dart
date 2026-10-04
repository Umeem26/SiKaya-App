// Tab Lainnya: pintu ke layar lama Pengaturan & Cadangan dan Inventaris
// (isi layar itu dirombak di S4).
import 'package:flutter/material.dart';

import 'list_asset_page.dart';
import 'settings_page.dart';
import 'ui/tokens.dart';

class LainnyaPage extends StatelessWidget {
  const LainnyaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Menu(
            ikon: Icons.save_alt,
            judul: 'Cadangan & Pengaturan',
            keterangan: 'Ekspor dan pulihkan cadangan, tutup buku, ekspor CSV, hapus data',
            buka: (_) => const SettingsPage(),
          ),
          const SizedBox(height: 12),
          _Menu(
            ikon: Icons.inventory_2_outlined,
            judul: 'Inventaris',
            keterangan: 'Daftar ternak, barang, dan peralatan (tidak masuk laporan keuangan)',
            buka: (_) => const ListAssetPage(),
          ),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.ikon, required this.judul, required this.keterangan, required this.buka});
  final IconData ikon;
  final String judul;
  final String keterangan;
  final WidgetBuilder buka;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: buka)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(ikon, size: 32, color: Warna.primer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(judul, style: t.titleSmall),
                  const SizedBox(height: 4),
                  Text(keterangan, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Warna.teksSekunder),
            ]),
          ),
        ),
      ),
    );
  }
}
