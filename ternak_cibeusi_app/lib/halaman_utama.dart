// Kerangka aplikasi: navigasi bawah berlabel (UI-PLAN.md bagian 3).
// Isi tab Catatan/Laporan/Lainnya masih layar lama (dirombak di S2-S4).
import 'package:flutter/material.dart';

import 'beranda_page.dart';
import 'lainnya_page.dart';
import 'list_finance_page.dart';
import 'report_page.dart';
import 'ui/tokens.dart';

class TujuanNavigasi {
  const TujuanNavigasi(this.label, this.ikon, this.ikonAktif);
  final String label;
  final IconData ikon;
  final IconData ikonAktif;
}

const tujuanNavigasi = [
  TujuanNavigasi('Beranda', Icons.home_outlined, Icons.home),
  TujuanNavigasi('Catatan', Icons.receipt_long_outlined, Icons.receipt_long),
  TujuanNavigasi('Laporan', Icons.bar_chart_outlined, Icons.bar_chart),
  TujuanNavigasi('Lainnya', Icons.menu, Icons.menu_open),
];

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key, this.muatBeranda});

  /// Pengganti pemuat data Beranda (tes); null = data aplikasi.
  final Future<RingkasanBeranda> Function()? muatBeranda;

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  int _tab = 0;

  void _pindah(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    // Halaman dibuat ulang setiap pindah tab agar datanya selalu terbaru.
    final halaman = switch (_tab) {
      0 => widget.muatBeranda == null
          ? BerandaPage(onLihatCatatan: () => _pindah(1))
          : BerandaPage(muat: widget.muatBeranda!, onLihatCatatan: () => _pindah(1)),
      1 => const ListFinancePage(),
      2 => const ReportPage(),
      _ => const LainnyaPage(),
    };
    return Scaffold(
      body: halaman,
      bottomNavigationBar: NavigasiBawah(terpilih: _tab, onPilih: _pindah),
    );
  }
}

/// Navigasi bawah: ikon + tulisan selalu tampil, tinggi ikut ukuran huruf.
/// Tulisan hanya mengecil (FittedBox) bila tidak muat di lebar kolomnya.
class NavigasiBawah extends StatelessWidget {
  const NavigasiBawah({super.key, required this.terpilih, required this.onPilih});
  final int terpilih;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Warna.permukaan,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tujuanNavigasi.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == terpilih,
                  button: true,
                  child: InkWell(
                    onTap: () => onPilih(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: i == terpilih ? Warna.primerMuda : null,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                i == terpilih ? tujuanNavigasi[i].ikonAktif : tujuanNavigasi[i].ikon,
                                color: i == terpilih ? Warna.primer : Warna.teksSekunder,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tujuanNavigasi[i].label,
                                maxLines: 1,
                                style: t.labelMedium!.copyWith(
                                  color: i == terpilih ? Warna.primer : Warna.teksSekunder,
                                  fontWeight: i == terpilih ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
