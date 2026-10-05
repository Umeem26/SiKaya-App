// Beranda (UI-PLAN.md bagian 3.1): keadaan usaha bulan ini dalam 5 detik.
// Semua angka dari AccountingRepository.loadReport (satu sumber kebenaran);
// layar ini tidak menghitung akuntansi sendiri. Ringkasan aset dari DataAset
// (aset_data.dart), sumber yang sama dengan tab Aset dan Laporan.
// Tampilan mengikuti UI lama (docs/ref-lama): header biru melengkung dengan
// sapaan dan nama usaha, kartu utama bergradien yang menumpuk ke header.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'aset_data.dart';
import 'detail_catatan_page.dart';
import 'form_finance_page.dart';
import 'transaction_model.dart';
import 'ui/item_catatan.dart';
import 'ui/komponen.dart';
import 'ui/theme.dart';
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
    this.terakhir = const [],
    this.aset,
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

  /// 5 catatan terbaru (urut tanggal lalu id, turun), termasuk yang perlu dicek.
  final List<TransactionModel> terakhir;

  /// Ringkasan aset & stok per [sampai] (sumber sama dengan tab Aset); null = tidak dimuat.
  final DataAset? aset;
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
    terakhir: (await repo.transactions()).take(5).toList(),
    aset: await muatDataAset(repo, hariIni: sampai),
  );
}

Future<RingkasanBeranda> muatBerandaAplikasi(AccountingRepository repo, {DateTime? hariIni}) async {
  final prefs = await SharedPreferences.getInstance();
  return muatRingkasanBeranda(
    repo,
    hariIni: hariIni ?? DateTime.now(),
    namaUsaha: prefs.getString('owner_name') ?? 'Usaha Saya',
  );
}

String teksPeriode(DateTime dari, DateTime sampai) =>
    'Bulan ini: ${dari.day}–${sampai.day} ${namaBulan[sampai.month - 1]} ${sampai.year}';

/// Sapaan menurut jam (header Beranda).
String sapaan(DateTime t) => switch (t.hour) {
      < 11 => 'Selamat pagi',
      < 15 => 'Selamat siang',
      < 18 => 'Selamat sore',
      _ => 'Selamat malam',
    };

/// Mulai skala huruf ini Beranda ringkas: header lebih pendek dan tombol
/// "Apa yang terjadi?" ikut tergulir (tidak dipin) agar layar pertama berisi angka.
const skalaBerandaRingkas = 1.5;

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key, this.muat, this.repo, this.hariIni, this.onLihatCatatan, this.onLihatAset});

  /// Pemuat data (tes); null = [muatBerandaAplikasi] dari [repo].
  final Future<RingkasanBeranda> Function()? muat;
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  /// Pindah ke daftar catatan (tab Catat) untuk memeriksa yang perlu dicek.
  final VoidCallback? onLihatCatatan;

  /// Pindah ke tab Aset.
  final VoidCallback? onLihatAset;

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  late Future<RingkasanBeranda> _data = _muat();

  Future<RingkasanBeranda> _muat() =>
      widget.muat?.call() ??
      muatBerandaAplikasi(widget.repo ?? AccountingRepository.instance, hariIni: widget.hariIni);

  void _muatUlang() {
    setState(() {
      _data = _muat();
    });
  }

  Future<void> _buka(Widget halaman) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => halaman));
    if (mounted) _muatUlang();
  }

  Future<void> _catat() => _buka(FormFinancePage(repo: widget.repo, hariIni: widget.hariIni));

  bool get _ringkas => MediaQuery.textScalerOf(context).scale(10) >= 10 * skalaBerandaRingkas;

  Widget get _tombolCatat =>
      TombolUtama(label: 'Apa yang terjadi?', ikon: Icons.edit_note_rounded, onPressed: _catat);

  @override
  Widget build(BuildContext context) {
    // Tanpa app bar: header merek sampai ke balik status bar (ikon status putih).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: gayaSistem,
      child: Scaffold(
        // Aksi utama selalu terlihat, tidak ikut tergulir; pada huruf sangat besar ikut
        // tergulir (di bawah kartu utama) agar tidak memakan layar bersama navigasi.
        bottomNavigationBar: _ringkas
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s8, Jarak.s16, Jarak.s8),
                  child: _tombolCatat,
                ),
              ),
        body: FutureBuilder<RingkasanBeranda>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return SafeArea(
                child: ListView(padding: const EdgeInsets.all(Jarak.s16), children: [
                  BannerPeringatan(
                    judul: 'Data tidak bisa dibaca',
                    isi: '${snap.error}',
                    nada: Nada.error,
                    aksi: 'Coba lagi',
                    ikonAksi: Icons.refresh_rounded,
                    onAksi: _muatUlang,
                  ),
                ]),
              );
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            // Status bar transparan: beri latar biru agar ikon status tetap terbaca saat isi digulir.
            return Stack(children: [
              RefreshIndicator(
                onRefresh: () async => _muatUlang(),
                child: _isi(snap.data!),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: const ColoredBox(color: Warna.primer),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _kepala(RingkasanBeranda r, double tumpuk) {
    final t = Theme.of(context).textTheme;
    final ringkas = _ringkas;
    return HeaderMerek(
      atas: ringkas ? Jarak.s8 : Jarak.s16,
      bawah: tumpuk + (ringkas ? Jarak.s12 : Jarak.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sapaan hanya hiasan: tidak ditampilkan bila huruf sangat besar agar nama usaha muat utuh.
              if (MediaQuery.textScalerOf(context).scale(10) <= 15) ...[
                Text('${sapaan(widget.hariIni ?? DateTime.now())}, Juragan',
                    style: t.bodyLarge!.copyWith(color: Warna.primerPudar)),
                const SizedBox(height: Jarak.s4),
              ],
              // Nama usaha hanya judul: maks 3 baris (2 bila ringkas) agar angka penting tetap muat.
              Text(r.namaUsaha,
                  style: t.titleLarge!.copyWith(color: Warna.putih),
                  maxLines: ringkas ? 2 : 3,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          // Logo hanya hiasan: disembunyikan pada huruf sangat besar agar header pendek.
          if (!ringkas) ...[
            const SizedBox(width: Jarak.s12),
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(Jarak.s4),
              decoration: const BoxDecoration(color: Warna.putih, shape: BoxShape.circle),
              child: ClipOval(child: Image.asset('assets/icon_ayam.png', fit: BoxFit.contain)),
            ),
          ],
        ]),
        SizedBox(height: ringkas ? Jarak.s8 : Jarak.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
          decoration: BoxDecoration(color: const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(999)),
          child: Text.rich(
            TextSpan(children: [
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.calendar_month_rounded, size: 18, color: Warna.putih),
              ),
              TextSpan(text: ' ${teksPeriode(r.dari, r.sampai)}'),
            ]),
            style: t.bodySmall!.copyWith(color: Warna.putih, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _isi(RingkasanBeranda r) {
    final untung = r.labaBersih >= 0;
    const jarak = SizedBox(height: Jarak.s16);
    final tumpuk = _ringkas ? 24.0 : 48.0; // kartu utama naik ke header sebanyak ini
    final aset = r.aset;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _kepala(r, tumpuk),
        // Isi naik menumpuk ke header (gaya UI lama); ruang kosong di ujung bawah daftar = tumpuk.
        Transform.translate(
          offset: Offset(0, -tumpuk),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KartuAngka(
                utama: true,
                judul: untung ? 'Untung bulan ini' : 'Rugi bulan ini',
                nilai: rupiah(r.labaBersih.abs()),
                ikon: untung ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                nada: untung ? Nada.sukses : Nada.error,
                keterangan: 'Penjualan dikurangi biaya yang terpakai bulan ini, termasuk pakan '
                    'dan penyusutan. Uang masuk belum tentu untung.',
              ),
              if (_ringkas) ...[jarak, _tombolCatat],
              if (r.perluDitinjau case final w?) ...[
                jarak,
                BannerPeringatan(
                  judul: '${w.jumlahTransaksi} catatan perlu dicek',
                  isi: 'Catatan ini belum dihitung dalam angka di bawah (total ${rupiah(w.totalNilai)}). '
                      'Buka Catatan, lalu ubah atau hapus yang salah.',
                  aksi: 'Lihat catatan',
                  ikonAksi: Icons.list_alt_rounded,
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
              KisiKartu(children: [
                KartuAngka(
                  judul: 'Uang masuk',
                  nilai: bertanda(r.uangMasuk),
                  ikon: Icons.south_west_rounded,
                  nada: Nada.sukses,
                  keterangan: 'Penjualan tunai, pelunasan piutang, pinjaman, dan modal.',
                ),
                KartuAngka(
                  judul: 'Uang keluar',
                  nilai: bertanda(-r.uangKeluar),
                  ikon: Icons.north_east_rounded,
                  nada: Nada.peringatan,
                  keterangan: 'Belanja, biaya, cicilan, dan ambilan pribadi.',
                ),
              ]),
              jarak,
              KartuAngka(
                judul: 'Uang kas sekarang',
                nilai: rupiah(r.kasSekarang),
                ikon: Icons.account_balance_wallet_rounded,
                keterangan: 'Sisa uang tunai menurut catatan.',
              ),
              if (aset != null) ...[
                const SizedBox(height: Jarak.s24),
                JudulSeksi('Aset & stok',
                    aksi: widget.onLihatAset == null ? null : 'Lihat aset', onAksi: widget.onLihatAset),
                const SizedBox(height: Jarak.s8),
                ..._aset(aset),
              ],
              const SizedBox(height: Jarak.s24),
              const JudulSeksi('Catatan terakhir'),
              const SizedBox(height: Jarak.s8),
              if (r.terakhir.isEmpty)
                const Card(
                  child: KosongRamah(
                    ikon: Icons.edit_note_rounded,
                    judul: 'Belum ada catatan',
                    isi: 'Belum ada catatan. Tekan "Apa yang terjadi?" di bawah untuk mencatat.',
                  ),
                ),
              for (final c in r.terakhir) ...[
                ItemCatatan(catatan: c, onTap: () => _buka(DetailCatatanPage(catatan: c, repo: widget.repo))),
                const SizedBox(height: Jarak.s8),
              ],
              if (r.terakhir.isNotEmpty && widget.onLihatCatatan != null) ...[
                const SizedBox(height: Jarak.s4),
                TombolKedua(
                    label: 'Lihat semua catatan', ikon: Icons.list_alt_rounded, onPressed: widget.onLihatCatatan),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  /// Ringkasan aset: nilai buku aset tetap, nilai stok, jumlah ternak, stok menipis.
  List<Widget> _aset(DataAset a) {
    if (!a.adaData) {
      return [
        Card(
          child: KosongRamah(
            ikon: Icons.warehouse_rounded,
            judul: 'Belum ada aset atau stok',
            isi: 'Catat pembelian kandang, alat, pakan, atau bibit. Nilainya muncul di sini.',
            aksi: widget.onLihatAset == null ? null : 'Buka Aset',
            ikonAksi: Icons.arrow_forward_rounded,
            onAksi: widget.onLihatAset,
          ),
        ),
      ];
    }
    final ternak = a.stokDari(StockItem.ternak);
    final menipis = a.menipis;
    return [
      KisiKartu(children: [
        KartuAngka(
          judul: 'Kandang & peralatan',
          nilai: rupiah(a.nilaiBukuAsetTetap),
          ikon: Icons.warehouse_rounded,
          keterangan: '${a.asetTetap.length} aset, nilai sesudah penyusutan.',
        ),
        KartuAngka(
          judul: 'Nilai stok',
          nilai: rupiah(a.nilaiPersediaan),
          ikon: Icons.inventory_2_rounded,
          keterangan: 'Pakan, obat, dan ternak menurut harga beli.',
        ),
        if (ternak.pernahDibeli)
          KartuAngka(
            judul: 'Jumlah ternak',
            nilai: '${ribuan(ternak.jumlah)} ekor',
            ikon: Icons.pets_rounded,
            keterangan: 'Dari catatan beli bibit, jual, dan mati.',
          ),
      ]),
      if (menipis.isNotEmpty) ...[
        const SizedBox(height: Jarak.s16),
        BannerPeringatan(
          judul: 'Stok menipis',
          isi: [
            for (final s in menipis)
              s.jumlah == 0
                  ? '${namaBarang(s.item)}: habis'
                  : '${namaBarang(s.item)}: sisa ${ribuan(s.jumlah)} ${satuanBarang(s.item)}, cukup ±${s.cukupHari} hari',
          ].join('\n'),
          aksi: widget.onLihatAset == null ? null : 'Lihat stok',
          ikonAksi: Icons.inventory_2_rounded,
          onAksi: widget.onLihatAset,
        ),
      ],
    ];
  }
}
