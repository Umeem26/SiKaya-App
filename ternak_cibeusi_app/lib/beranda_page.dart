// Beranda (UI-PLAN.md bagian 3.1): keadaan usaha bulan ini dalam 5 detik.
// Semua angka dari AccountingRepository.loadReport (satu sumber kebenaran);
// layar ini tidak menghitung akuntansi sendiri.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'form_finance_page.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class RingkasanBeranda {
  const RingkasanBeranda({
    required this.namaUsaha,
    required this.dari,
    required this.sampai,
    required this.uangMasuk,
    required this.uangKeluar,
    required this.kasSekarang,
    required this.labaBersih,
    this.perluDitinjau,
    this.seimbang = true,
  });
  final String namaUsaha;
  final DateTime dari;
  final DateTime sampai;

  /// Buku kas selama [dari, sampai].
  final int uangMasuk;
  final int uangKeluar;

  /// Saldo buku kas per [sampai].
  final int kasSekarang;

  /// Laba Rugi [dari, sampai].
  final int labaBersih;
  final ReviewWarning? perluDitinjau;
  final bool seimbang;
}

/// Ringkasan bulan berjalan s.d. [hariIni]. Kas periode = buku kas per hariIni
/// dikurangi buku kas per akhir bulan lalu (keduanya dari loadReport); validitas
/// transaksi tidak berubah oleh tanggal laporan, jadi selisihnya = transaksi bulan ini.
Future<RingkasanBeranda> muatRingkasanBeranda(
  AccountingRepository repo, {
  required DateTime hariIni,
  required String namaUsaha,
}) async {
  final sampai = DateTime(hariIni.year, hariIni.month, hariIni.day);
  final dari = DateTime(sampai.year, sampai.month, 1);
  final p = await repo.loadReport(asOf: sampai, from: dari);
  final awal = (await repo.loadReport(asOf: DateTime(dari.year, dari.month, 0))).kas;
  return RingkasanBeranda(
    namaUsaha: namaUsaha,
    dari: dari,
    sampai: sampai,
    uangMasuk: p.kas.masuk - awal.masuk,
    uangKeluar: p.kas.keluar - awal.keluar,
    kasSekarang: p.kas.saldo,
    labaBersih: p.report.labaBersih,
    perluDitinjau: p.report.peringatanTinjau,
    seimbang: p.report.balanced,
  );
}

Future<RingkasanBeranda> _muatDariAplikasi() async {
  final prefs = await SharedPreferences.getInstance();
  return muatRingkasanBeranda(
    AccountingRepository.instance,
    hariIni: DateTime.now(),
    namaUsaha: prefs.getString('owner_name') ?? 'Usaha Saya',
  );
}

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String teksPeriode(DateTime dari, DateTime sampai) =>
    'Bulan ini: ${dari.day}–${sampai.day} ${_bulan[sampai.month - 1]} ${sampai.year}';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key, this.muat = _muatDariAplikasi, this.onLihatCatatan});

  final Future<RingkasanBeranda> Function() muat;

  /// Pindah ke daftar catatan (tab Catatan) untuk memeriksa yang perlu dicek.
  final VoidCallback? onLihatCatatan;

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  late Future<RingkasanBeranda> _data = widget.muat();

  void _muatUlang() {
    setState(() {
      _data = widget.muat();
    });
  }

  Future<void> _catat() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FormFinancePage()));
    if (mounted) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      // Aksi utama selalu terlihat, tidak ikut tergulir.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(label: 'Apa yang terjadi?', ikon: Icons.edit_note, onPressed: _catat),
        ),
      ),
      body: FutureBuilder<RingkasanBeranda>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              BannerPeringatan(
                judul: 'Data tidak bisa dibaca',
                isi: '${snap.error}',
                nada: Nada.error,
                aksi: 'Coba lagi',
                ikonAksi: Icons.refresh,
                onAksi: _muatUlang,
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async => _muatUlang(),
            child: _isi(snap.data!),
          );
        },
      ),
    );
  }

  Widget _isi(RingkasanBeranda r) {
    final t = Theme.of(context).textTheme;
    final untung = r.labaBersih >= 0;
    const jarak = SizedBox(height: 16);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nama usaha hanya judul: maks 2 baris agar angka penting tetap muat di layar.
        Text(r.namaUsaha, style: t.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(teksPeriode(r.dari, r.sampai), style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        if (r.perluDitinjau case final w?) ...[
          jarak,
          BannerPeringatan(
            judul: '${w.jumlahTransaksi} catatan perlu dicek',
            isi: 'Catatan ini belum dihitung dalam angka di bawah (total ${rupiah(w.totalNilai)}). '
                'Buka Catatan, lalu ubah atau hapus yang salah.',
            aksi: 'Lihat catatan',
            ikonAksi: Icons.list_alt,
            onAksi: widget.onLihatCatatan,
          ),
        ],
        if (!r.seimbang) ...[
          jarak,
          const BannerPeringatan(
            judul: 'Laporan tidak seimbang',
            isi: 'Jumlah harta tidak sama dengan utang ditambah modal. '
                'Jangan tutup buku dulu; minta bantuan pendamping untuk memeriksa catatan.',
            nada: Nada.error,
          ),
        ],
        jarak,
        KartuAngka(
          judul: 'Uang masuk',
          nilai: bertanda(r.uangMasuk),
          ikon: Icons.south_west,
          nada: Nada.sukses,
          keterangan: 'Uang yang diterima bulan ini: penjualan tunai, pelunasan piutang, '
              'pinjaman, dan modal.',
        ),
        jarak,
        KartuAngka(
          judul: 'Uang keluar',
          nilai: bertanda(-r.uangKeluar),
          ikon: Icons.north_east,
          keterangan: 'Uang yang dibayarkan bulan ini: belanja, biaya, cicilan, dan ambilan pribadi.',
        ),
        jarak,
        KartuAngka(
          judul: untung ? 'Untung bulan ini' : 'Rugi bulan ini',
          nilai: rupiah(r.labaBersih.abs()),
          ikon: untung ? Icons.trending_up : Icons.trending_down,
          nada: untung ? Nada.sukses : Nada.error,
          keterangan: 'Penjualan dikurangi biaya yang terpakai bulan ini, termasuk pakan '
              'dan penyusutan. Uang masuk belum tentu untung.',
        ),
        jarak,
        KartuAngka(
          judul: 'Uang kas sekarang',
          nilai: rupiah(r.kasSekarang),
          ikon: Icons.account_balance_wallet_outlined,
          keterangan: 'Sisa uang tunai menurut catatan.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
