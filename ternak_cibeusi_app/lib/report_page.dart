// Laporan lapis 1: Ringkasan berbahasa petani (UI-PLAN.md 3.4). Setiap angka
// disertai satu kalimat penjelasan; istilah resmi hanya di "Lihat laporan resmi".
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounting/repository.dart';
import 'laporan_data.dart';
import 'laporan_resmi_page.dart';
import 'ui/alasan.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, this.repo, this.hariIni, this.bagikan});
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  /// Pengganti fungsi bagikan PDF (tes); null = lembar bagikan Android.
  final Future<void> Function(Uint8List pdf, String namaFile)? bagikan;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;
  PilihanPeriode _pilihan = PilihanPeriode.bulanIni;
  DateTime? _dari, _sampai;
  late Future<DataLaporan> _data = _muat();

  /// Tanggal tutup buku terakhir (lencana "Ditutup"); gagal dibaca = tanpa lencana.
  late final Future<DateTime?> _kunci = _repo.lockedUntil().then<DateTime?>((k) => k, onError: (_) => null);

  DateTime get _hariIni => widget.hariIni ?? DateTime.now();

  Future<DataLaporan> _muat() async {
    final prefs = await SharedPreferences.getInstance();
    final p = hitungPeriode(_pilihan, _hariIni, dari: _dari, sampai: _sampai);
    return muatDataLaporan(_repo,
        dari: p.dari, sampai: p.sampai, namaUsaha: prefs.getString('owner_name') ?? 'Usaha Saya');
  }

  Future<void> _pilihPeriode(PilihanPeriode p) async {
    if (p == PilihanPeriode.pilihTanggal) {
      final awal = hitungPeriode(_pilihan, _hariIni, dari: _dari, sampai: _sampai);
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: awal.dari, end: awal.sampai),
        helpText: 'Pilih tanggal awal dan akhir',
        saveText: 'Pilih',
        cancelText: 'Batal',
      );
      if (r == null) return;
      _dari = r.start;
      _sampai = r.end;
    }
    setState(() {
      _pilihan = p;
      _data = _muat();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: FutureBuilder<DataLaporan>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              BannerPeringatan(
                judul: 'Laporan tidak bisa dibuat',
                isi: '${snap.error}',
                nada: Nada.error,
                aksi: 'Coba lagi',
                ikonAksi: Icons.refresh_rounded,
                onAksi: () => setState(() {
                  _data = _muat();
                }),
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return FutureBuilder<DateTime?>(future: _kunci, builder: (context, k) => _ringkasan(snap.data!, k.data));
        },
      ),
      bottomNavigationBar: FutureBuilder<DataLaporan>(
        future: _data,
        builder: (context, snap) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TombolUtama(
              label: 'Lihat laporan resmi',
              ikon: Icons.description_rounded,
              onPressed: snap.data == null
                  ? null
                  : () async {
                      final kunci = await _kunci;
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LaporanResmiPage(data: snap.data!, bagikan: widget.bagikan, ditutupSampai: kunci)),
                      );
                    },
            ),
          ),
        ),
      ),
    );
  }

  Widget _ringkasan(DataLaporan d, DateTime? ditutupSampai) {
    final t = Theme.of(context).textTheme;
    final untung = d.untungRugi >= 0;
    const jarak = SizedBox(height: Jarak.s12);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, Jarak.s24),
      children: [
        Text('Pilih waktu', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Jarak.s8),
        Wrap(spacing: Jarak.s8, runSpacing: Jarak.s8, children: [
          for (final p in PilihanPeriode.values)
            TombolPilihan(
              label: labelPeriode[p]!,
              terpilih: p == _pilihan,
              ikon: Icons.calendar_month_rounded,
              onPressed: () => _pilihPeriode(p),
            ),
        ]),
        const SizedBox(height: Jarak.s16),
        // Kop ringkasan: nama usaha dan rentang waktu yang sedang dilihat.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Jarak.s16),
            child: Row(children: [
              const UbinIkon(Icons.event_note_rounded),
              const SizedBox(width: Jarak.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.namaUsaha, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                  Text('${tanggalResmi(d.dari)} s.d. ${tanggalResmi(d.sampai)}',
                      style: t.titleSmall!.copyWith(color: Warna.primer, fontWeight: FontWeight.w700)),
                  if (ditutupSampai != null && !d.dari.isAfter(ditutupSampai))
                    LencanaDitutup(
                        label: labelDitutup(ditutupSampai), onTap: () => jelaskanDitutup(context, ditutupSampai)),
                ]),
              ),
            ]),
          ),
        ),
        if (d.r.peringatanTinjau case final w?) ...[
          jarak,
          BannerPeringatan(
            judul: '${w.jumlahTransaksi} catatan perlu dicek',
            isi: 'Catatan ini belum dihitung dalam angka di bawah (total ${rupiah(w.totalNilai)}). '
                'Periksa di menu Catatan.',
          ),
        ],
        if (!d.r.balanced) ...[
          jarak,
          const BannerPeringatan(
            judul: 'Laporan tidak seimbang',
            isi: 'Jumlah harta tidak sama dengan utang ditambah modal. Minta bantuan pendamping '
                'untuk memeriksa catatan.',
            nada: Nada.error,
          ),
        ],
        const SizedBox(height: Jarak.s16),
        KartuAngka(
          utama: true,
          judul: untung ? 'Untung' : 'Rugi',
          nilai: rupiah(d.untungRugi.abs()),
          ikon: untung ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          nada: untung ? Nada.sukses : Nada.error,
          keterangan: 'Penjualan ${rupiah(d.penjualan)} dikurangi biaya ${rupiah(d.biaya)}, termasuk pakan '
              'yang terpakai dan penyusutan. Uang masuk belum tentu untung.',
        ),
        jarak,
        KisiKartu(children: [
          KartuAngka(
            judul: 'Uang masuk',
            nilai: bertanda(d.uangMasuk),
            ikon: Icons.south_west_rounded,
            nada: Nada.sukses,
            keterangan: 'Uang tunai diterima: penjualan tunai, pelunasan piutang, pinjaman, modal.',
          ),
          KartuAngka(
            judul: 'Uang keluar',
            nilai: bertanda(-d.uangKeluar),
            ikon: Icons.north_east_rounded,
            nada: Nada.peringatan,
            keterangan: 'Uang tunai dibayar: belanja, biaya, cicilan, ambilan pribadi.',
          ),
        ]),
        const SizedBox(height: Jarak.s24),
        JudulSeksi('Posisi pada ${tanggalResmi(d.sampai)}'),
        const SizedBox(height: Jarak.s8),
        KisiKartu(children: [
          KartuAngka(
            judul: 'Uang kas di akhir waktu ini',
            nilai: rupiah(d.kasAkhir),
            ikon: Icons.account_balance_wallet_rounded,
            keterangan: 'Sisa uang tunai usaha menurut catatan.',
          ),
          KartuAngka(
            judul: 'Nilai stok',
            nilai: rupiah(d.nilaiStok),
            ikon: Icons.inventory_2_rounded,
            keterangan: 'Pakan, obat, dan ternak yang masih ada, dari harga beli rata-rata.',
          ),
          KartuAngka(
            judul: 'Nilai kandang & peralatan',
            nilai: rupiah(d.nilaiAsetTetap),
            ikon: Icons.warehouse_rounded,
            keterangan: 'Harga beli dikurangi penyusutan (bagian yang sudah terpakai).',
          ),
          KartuAngka(
            judul: 'Utang',
            nilai: rupiah(d.utang),
            ikon: Icons.call_made_rounded,
            nada: d.utang > 0 ? Nada.peringatan : Nada.netral,
            keterangan: 'Yang masih harus Anda bayar ke penjual atau pemberi pinjaman.',
          ),
          KartuAngka(
            judul: 'Piutang',
            nilai: rupiah(d.piutang),
            ikon: Icons.call_received_rounded,
            keterangan: 'Yang masih harus dibayar pembeli kepada Anda.',
          ),
        ]),
      ],
    );
  }
}
