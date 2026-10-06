// Kerangka aplikasi: navigasi bawah berlabel (UI-PLAN.md bagian 3).
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'accounting/repository.dart';
import 'aset_page.dart';
import 'foto_aset.dart';
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

/// Lima tujuan berlabel pendek (muat 5 kolom di 360dp, huruf 2,0x).
const tujuanNavigasi = [
  TujuanNavigasi('Beranda', Icons.home_rounded, Icons.home_rounded),
  TujuanNavigasi('Catat', Icons.edit_note_rounded, Icons.edit_note_rounded),
  TujuanNavigasi('Aset', Icons.warehouse_rounded, Icons.warehouse_rounded),
  TujuanNavigasi('Laporan', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
  TujuanNavigasi('Lainnya', Icons.more_horiz_rounded, Icons.more_horiz_rounded),
];

/// Indeks tab (urutan [tujuanNavigasi]).
abstract final class TabUtama {
  static const beranda = 0, catat = 1, aset = 2, laporan = 3, lainnya = 4;
}

/// Pindah ke tab utama [tab] dari halaman mana pun, mis. tombol pintas di lembar
/// alasan: halaman yang ditumpuk di atas HalamanUtama ditutup dulu. Tanpa
/// HalamanUtama (tes satu halaman) tidak berbuat apa-apa.
void pindahKeTab(int tab) => _HalamanUtamaState._aktif?._keTab(tab);

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key, this.muatBeranda, this.repo, this.hariIni, this.bagikanPdf, this.fotoAset});

  /// Pengganti pemuat data Beranda (tes); null = data aplikasi.
  final Future<RingkasanBeranda> Function()? muatBeranda;

  /// Pengganti repository aplikasi (tes); null = AccountingRepository.instance.
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  /// Pengganti lembar bagikan PDF laporan (tes); null = lembar bagikan Android.
  final Future<void> Function(Uint8List pdf, String namaFile)? bagikanPdf;

  /// Pengganti sumber foto aset (tes); null = folder dokumen aplikasi.
  final SumberFotoAset? fotoAset;

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  /// HalamanUtama yang sedang tampil (hanya satu dalam aplikasi).
  static _HalamanUtamaState? _aktif;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _aktif = this;
  }

  @override
  void dispose() {
    if (_aktif == this) _aktif = null;
    super.dispose();
  }

  void _pindah(int i) => setState(() => _tab = i);

  void _keTab(int i) {
    if (!mounted) return;
    final rute = ModalRoute.of(context);
    if (rute != null) Navigator.of(context).popUntil((r) => r == rute);
    _pindah(i);
  }

  @override
  Widget build(BuildContext context) {
    // Halaman dibuat ulang setiap pindah tab agar datanya selalu terbaru.
    final halaman = switch (_tab) {
      TabUtama.beranda => BerandaPage(
          muat: widget.muatBeranda,
          repo: widget.repo,
          hariIni: widget.hariIni,
          onLihatCatatan: () => _pindah(TabUtama.catat),
          onLihatAset: () => _pindah(TabUtama.aset),
        ),
      TabUtama.catat => ListFinancePage(repo: widget.repo, hariIni: widget.hariIni),
      TabUtama.aset => AsetPage(repo: widget.repo, hariIni: widget.hariIni, foto: widget.fotoAset),
      TabUtama.laporan => ReportPage(repo: widget.repo, hariIni: widget.hariIni, bagikan: widget.bagikanPdf),
      _ => LainnyaPage(repo: widget.repo, hariIni: widget.hariIni),
    };
    return Scaffold(
      body: halaman,
      bottomNavigationBar: NavigasiBawah(terpilih: _tab, onPilih: _pindah),
    );
  }
}

/// Navigasi bawah: ikon + tulisan selalu tampil, tinggi ikut ukuran huruf.
/// Tulisan hanya mengecil (FittedBox) bila tidak muat di lebar kolomnya.
/// Tab terpilih: pil biru muda di belakang ikon, tulisan biru tebal, garis aksen.
class NavigasiBawah extends StatelessWidget {
  const NavigasiBawah({super.key, required this.terpilih, required this.onPilih});
  final int terpilih;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final skala = MediaQuery.textScalerOf(context);
    TextStyle gaya(bool aktif) => t.labelMedium!.copyWith(
          color: aktif ? Warna.primer : Warna.teksSekunder,
          fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
          height: 1.4,
          letterSpacing: -0.02 * skala.scale(16),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Warna.permukaan,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Warna.bayangan, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Tanpa jarak samping: 5 kolom x 72dp di layar 360dp, label sebesar mungkin.
          padding: const EdgeInsets.symmetric(vertical: Jarak.s4),
          child: LayoutBuilder(builder: (context, c) {
            // Satu faktor untuk semua label (dari label terlebar): ukuran tulisan seragam,
            // tidak ada label yang tampak lebih kecil dari yang lain.
            final lebarKolom = c.maxWidth / tujuanNavigasi.length - 2;
            var terlebar = 0.0;
            for (final tj in tujuanNavigasi) {
              final ukur = TextPainter(
                text: TextSpan(text: tj.label, style: gaya(true)),
                textDirection: Directionality.of(context),
                textScaler: skala,
                maxLines: 1,
              )..layout();
              if (ukur.width > terlebar) terlebar = ukur.width;
              ukur.dispose();
            }
            final faktor = terlebar <= lebarKolom ? 1.0 : lebarKolom / terlebar;
            final skalaLabel = TextScaler.linear(skala.scale(100) / 100 * faktor);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tujuanNavigasi.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == terpilih,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Sudut.kecil),
                        onTap: () => onPilih(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: Jarak.s8, horizontal: 1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
                                  decoration: BoxDecoration(
                                    color: i == terpilih ? Warna.primerMuda : null,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Icon(
                                    i == terpilih ? tujuanNavigasi[i].ikonAktif : tujuanNavigasi[i].ikon,
                                    color: i == terpilih ? Warna.primer : Warna.teksSekunder,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: Jarak.s4),
                                // FittedBox hanya pengaman pembulatan; ukuran sudah diatur faktor di atas.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tujuanNavigasi[i].label,
                                    maxLines: 1,
                                    textScaler: skalaLabel,
                                    style: gaya(i == terpilih),
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
            );
          }),
        ),
      ),
    );
  }
}
