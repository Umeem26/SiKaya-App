// Riwayat catatan (UI-PLAN.md bagian 3.3): daftar per bulan; ketuk satu catatan
// untuk melihat detail dengan tombol "Ubah" dan "Hapus" berlabel. Periode yang
// sudah ditutup buku berlencana "Ditutup" (bulan penuh: di judul bulan).
import 'package:flutter/material.dart';

import 'accounting/repository.dart';
import 'detail_catatan_page.dart';
import 'form_finance_page.dart';
import 'transaction_model.dart';
import 'ui/alasan.dart';
import 'ui/item_catatan.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class ListFinancePage extends StatefulWidget {
  const ListFinancePage({super.key, this.repo, this.hariIni});
  final AccountingRepository? repo;

  /// Pengganti "sekarang" untuk form catat (tes); null = DateTime.now().
  final DateTime? hariIni;

  @override
  State<ListFinancePage> createState() => _ListFinancePageState();
}

class _ListFinancePageState extends State<ListFinancePage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;
  late Future<List<TransactionModel>> _data = _repo.transactions();
  late Future<DateTime?> _kunci = _bacaKunci();
  bool _hanyaPerluDicek = false;

  /// Gagal membaca tanggal tutup buku tidak menghalangi daftar (lencana saja yang hilang).
  Future<DateTime?> _bacaKunci() => _repo.lockedUntil().then<DateTime?>((k) => k, onError: (_) => null);

  void _muatUlang() {
    setState(() {
      _data = _repo.transactions();
      _kunci = _bacaKunci();
    });
  }

  Future<void> _buka(Widget halaman) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => halaman));
    if (mounted) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(
            label: 'Apa yang terjadi?',
            ikon: Icons.edit_note_rounded,
            onPressed: () => _buka(FormFinancePage(repo: widget.repo, hariIni: widget.hariIni)),
          ),
        ),
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              BannerPeringatan(
                judul: 'Catatan tidak bisa dibaca',
                isi: '${snap.error}',
                nada: Nada.error,
                aksi: 'Coba lagi',
                ikonAksi: Icons.refresh_rounded,
                onAksi: _muatUlang,
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return FutureBuilder<DateTime?>(
            future: _kunci,
            builder: (context, k) => _daftar(snap.data!, k.data),
          );
        },
      ),
    );
  }

  Widget _daftar(List<TransactionModel> semua, DateTime? ditutupSampai) {
    final t = Theme.of(context).textTheme;
    final perluDicek = semua.where((c) => c.perluDitinjau).length;
    final tampil = _hanyaPerluDicek ? semua.where((c) => c.perluDitinjau).toList() : semua;

    // Baris datar: judul bulan (String) atau catatan; data sudah urut tanggal turun.
    final baris = <Object>[];
    String? bulan;
    for (final c in tampil) {
      final b = c.date.length >= 7 ? c.date.substring(0, 7) : c.date;
      if (b != bulan) baris.add(bulan = b);
      baris.add(c);
    }

    final atas = <Widget>[
      if (perluDicek > 0)
        BannerPeringatan(
          judul: '$perluDicek catatan perlu dicek',
          isi: 'Catatan ini belum dihitung di laporan. Ketuk catatannya, lalu ubah atau hapus.',
          aksi: _hanyaPerluDicek ? 'Tampilkan semua catatan' : 'Tampilkan yang perlu dicek saja',
          ikonAksi: _hanyaPerluDicek ? Icons.list_rounded : Icons.filter_alt_rounded,
          onAksi: () => setState(() => _hanyaPerluDicek = !_hanyaPerluDicek),
        ),
      if (semua.isEmpty)
        const Card(
          child: KosongRamah(
            ikon: Icons.edit_note_rounded,
            judul: 'Belum ada catatan',
            isi: 'Belum ada catatan. Tekan "Apa yang terjadi?" di bawah untuk mencatat.',
          ),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () async => _muatUlang(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: atas.length + baris.length,
        itemBuilder: (context, i) {
          if (i < atas.length) {
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: atas[i]);
          }
          final b = baris[i - atas.length];
          if (b is String) {
            final n = tampil.where((c) => c.date.startsWith(b)).length;
            return Padding(
              padding: const EdgeInsets.only(top: Jarak.s12, bottom: Jarak.s8),
              child: Wrap(
                spacing: Jarak.s8,
                runSpacing: Jarak.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(header: true, child: Text(judulBulan(b), style: t.titleMedium)),
                  ChipPil('$n catatan'),
                  if (bulanDitutup(b, ditutupSampai))
                    LencanaDitutup(onTap: () => jelaskanDitutup(context, ditutupSampai!)),
                ],
              ),
            );
          }
          final c = b as TransactionModel;
          final bulan = c.date.length >= 7 ? c.date.substring(0, 7) : c.date;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ItemCatatan(
              catatan: c,
              // Bulan yang ditutup sebagian: lencana per catatan (bulan penuh sudah di judulnya).
              ditutup: sudahDitutup(c.date, ditutupSampai) && !bulanDitutup(bulan, ditutupSampai),
              onTap: () => _buka(DetailCatatanPage(catatan: c, repo: widget.repo)),
            ),
          );
        },
      ),
    );
  }
}

/// true bila seluruh bulan [yyyyMm] sudah ditutup buku (akhir bulan <= [ditutupSampai]).
bool bulanDitutup(String yyyyMm, DateTime? ditutupSampai) {
  final t = DateTime.tryParse('$yyyyMm-01');
  return t != null && ditutupSampai != null && !DateTime(t.year, t.month + 1, 0).isAfter(ditutupSampai);
}

/// "2026-10" -> "Oktober 2026".
String judulBulan(String yyyyMm) {
  final t = DateTime.tryParse('$yyyyMm-01');
  return t == null ? yyyyMm : '${namaBulan[t.month - 1]} ${t.year}';
}
