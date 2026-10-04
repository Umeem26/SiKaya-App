// Kerangka aplikasi: navigasi bawah berlabel (UI-PLAN.md bagian 3).
import 'package:flutter/material.dart';

import 'accounting/repository.dart';
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
  const HalamanUtama({super.key, this.muatBeranda, this.repo, this.hariIni});

  /// Pengganti pemuat data Beranda (tes); null = data aplikasi.
  final Future<RingkasanBeranda> Function()? muatBeranda;

  /// Pengganti repository aplikasi (tes); null = AccountingRepository.instance.
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

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
      0 => BerandaPage(
          muat: widget.muatBeranda,
          repo: widget.repo,
          hariIni: widget.hariIni,
          onLihatCatatan: () => _pindah(1),
        ),
      1 => ListFinancePage(repo: widget.repo, hariIni: widget.hariIni),
      2 => ReportPage(repo: widget.repo, hariIni: widget.hariIni),
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
