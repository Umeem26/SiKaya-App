// Tab Aset: kandang, alat & lahan (aset tetap mesin: foto, nilai perolehan, nilai
// buku, sisa umur manfaat), stok pakan/obat/ternak (jumlah dan nilai), dan pintu
// ke inventaris barang (tidak masuk laporan). Angka dari DataAset (aset_data.dart),
// sumber yang sama dengan Laporan; layar ini tidak menghitung akuntansi sendiri.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'accounting/engine.dart' show roundHalfAwayFromZero;
import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'aset_data.dart';
import 'detail_catatan_page.dart';
import 'foto_aset.dart';
import 'form_finance_page.dart';
import 'inventaris_data.dart';
import 'list_asset_page.dart';
import 'ui/item_catatan.dart';
import 'ui/komponen.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

const _bulanPendek = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// "Okt 2026".
String bulanPendek(DateTime t) => '${_bulanPendek[t.month - 1]} ${t.year}';

/// "Sisa 18 bulan" / "Sudah habis disusutkan" / "Tanah, tidak disusutkan".
String teksSisaUmur(AsetTetapTampil a) => switch (a.sisaBulan) {
      null => 'Tanah, tidak disusutkan',
      0 => 'Sudah habis disusutkan',
      final n => 'Sisa umur $n bulan',
    };

IconData ikonSisaUmur(AsetTetapTampil a) => a.disusutkan ? Icons.schedule_rounded : Icons.landscape_rounded;

IconData ikonStok(StockItem i) => switch (i) {
      StockItem.pakan => Icons.grass_rounded,
      StockItem.obat => Icons.vaccines_rounded,
      StockItem.ternak => Icons.pets_rounded,
    };

/// "Habis" / "Cukup ±3 hari" untuk stok menipis; null bila aman.
String? teksMenipis(StokTampil s) {
  if (!s.menipis) return null;
  return s.jumlah == 0 ? 'Habis' : 'Cukup ±${s.cukupHari} hari';
}

class AsetPage extends StatefulWidget {
  const AsetPage({super.key, this.repo, this.hariIni, this.foto, this.inventaris});
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  /// Sumber foto aset (tes: [SumberFotoAset.kosong]).
  final SumberFotoAset? foto;
  final SumberInventaris? inventaris;

  @override
  State<AsetPage> createState() => _AsetPageState();
}

class _AsetPageState extends State<AsetPage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;
  late Future<DataAset> _data = _muat();

  Future<DataAset> _muat() => muatDataAset(_repo, hariIni: widget.hariIni ?? DateTime.now());

  void _muatUlang() => setState(() {
        _data = _muat();
      });

  Future<void> _buka(Widget halaman) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => halaman));
    if (mounted) _muatUlang();
  }

  Future<void> _tambah() => _buka(FormFinancePage(repo: widget.repo, hariIni: widget.hariIni, jenisAwal: TxType.beliAsetTetap));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aset')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s8, Jarak.s16, Jarak.s8),
          child: TombolUtama(label: 'Tambah aset', ikon: Icons.add_rounded, onPressed: _tambah),
        ),
      ),
      body: FutureBuilder<DataAset>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(Jarak.s16), children: [
              BannerPeringatan(
                judul: 'Aset tidak bisa dibaca',
                isi: '${snap.error}',
                nada: Nada.error,
                aksi: 'Coba lagi',
                ikonAksi: Icons.refresh_rounded,
                onAksi: _muatUlang,
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(onRefresh: () async => _muatUlang(), child: _isi(snap.data!));
        },
      ),
    );
  }

  Widget _isi(DataAset d) {
    final foto = widget.foto ?? SumberFotoAset.instance;
    final adaStok = d.stok.any((s) => s.pernahDibeli);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, Jarak.s24),
      children: [
        KartuAngka(
          utama: true,
          judul: 'Nilai aset & stok',
          nilai: rupiah(d.nilaiBukuAsetTetap + d.nilaiPersediaan),
          ikon: Icons.account_balance_rounded,
          keterangan: 'Nilai buku kandang, alat & lahan ditambah nilai stok. Sama dengan Laporan Posisi Keuangan.',
        ),
        const SizedBox(height: Jarak.s24),
        const JudulSeksi('Kandang, alat & lahan'),
        const SizedBox(height: Jarak.s12),
        if (d.asetTetap.isEmpty)
          Card(
            child: KosongRamah(
              ikon: Icons.warehouse_rounded,
              judul: 'Belum ada aset tetap',
              isi: 'Catat pembelian kandang, alat, atau lahan. Nilainya akan disusutkan otomatis tiap bulan.',
              aksi: 'Tambah aset',
              onAksi: _tambah,
            ),
          ),
        for (final a in d.asetTetap) ...[
          KartuAsetTetap(
            aset: a,
            foto: foto,
            onTap: () => _buka(DetailAsetTetapPage(aset: a, repo: widget.repo, foto: foto)),
          ),
          const SizedBox(height: Jarak.s12),
        ],
        const SizedBox(height: Jarak.s12),
        const JudulSeksi('Stok pakan, obat & ternak'),
        const SizedBox(height: Jarak.s12),
        if (!adaStok)
          const Card(
            child: KosongRamah(
              ikon: Icons.inventory_2_rounded,
              judul: 'Belum ada stok',
              isi: 'Catat pembelian pakan, obat, atau bibit lewat tab Catat. Jumlah dan nilainya muncul di sini.',
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s4),
              child: Column(children: [
                for (var i = 0; i < d.stok.length; i++) ...[
                  if (i > 0) const Divider(),
                  BarisStok(stok: d.stok[i]),
                ],
              ]),
            ),
          ),
        const SizedBox(height: Jarak.s24),
        const JudulSeksi('Inventaris barang'),
        const SizedBox(height: Jarak.s12),
        KartuPilihan(
          judul: 'Daftar inventaris',
          penjelasan: 'Catatan barang, jumlah, kondisi, dan foto. Tidak masuk laporan keuangan.',
          ikon: Icons.photo_library_rounded,
          onTap: () => _buka(ListAssetPage(sumber: widget.inventaris)),
        ),
      ],
    );
  }
}

/// Foto aset (bila ada) atau ubin ikon; ukuran persegi [ukuran].
class FotoAset extends StatelessWidget {
  const FotoAset({super.key, required this.aset, required this.foto, this.ukuran = 64});
  final AsetTetapTampil aset;
  final SumberFotoAset foto;
  final double ukuran;

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
        future: foto.foto(aset.id, aset.idBeli),
        builder: (context, snap) {
          final f = snap.data;
          if (f == null) {
            return UbinIkon(aset.disusutkan ? Icons.warehouse_rounded : Icons.landscape_rounded, ukuran: ukuran);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(Sudut.kecil),
            child: Image.file(f, width: ukuran, height: ukuran, fit: BoxFit.cover, semanticLabel: 'Foto ${aset.nama}'),
          );
        },
      );
}

/// Kartu satu aset tetap: foto, nama, sisa umur, nilai perolehan dan nilai buku.
class KartuAsetTetap extends StatelessWidget {
  const KartuAsetTetap({super.key, required this.aset, required this.foto, this.onTap});
  final AsetTetapTampil aset;
  final SumberFotoAset foto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = aset;
    final bagian = a.hargaPerolehan == 0 ? 0.0 : a.akumulasi / a.hargaPerolehan;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Jarak.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FotoAset(aset: a, foto: foto),
              const SizedBox(width: Jarak.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.nama, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: Jarak.s4),
                  ChipPil(teksSisaUmur(a),
                      nada: a.sisaBulan == 0 ? Nada.peringatan : Nada.netral, ikon: ikonSisaUmur(a)),
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Warna.teksSekunder),
            ]),
            const SizedBox(height: Jarak.s12),
            BarisLaporan(label: 'Nilai perolehan', nilai: rupiah(a.hargaPerolehan)),
            BarisLaporan(label: 'Nilai buku', nilai: rupiah(a.nilaiBuku), tebal: true, warnaNilai: Warna.primer),
            if (a.disusutkan) ...[
              const SizedBox(height: Jarak.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: bagian.clamp(0, 1),
                  minHeight: 8,
                  color: Warna.aksen,
                  backgroundColor: Warna.primerMuda,
                  semanticsLabel: 'Sudah disusutkan',
                  semanticsValue: '${(bagian * 100).round()}',
                ),
              ),
              const SizedBox(height: Jarak.s4),
              Text('Sudah disusutkan ${(bagian * 100).round()}% dari ${a.umurBulan} bulan',
                  style: gayaAngka(t.bodySmall!.copyWith(color: Warna.teksSekunder))),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Satu baris stok: ikon, nama, jumlah, tanda menipis; nilai rata kanan.
class BarisStok extends StatelessWidget {
  const BarisStok({super.key, required this.stok});
  final StokTampil stok;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = stok;
    final menipis = teksMenipis(s);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jarak.s12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UbinIkon(ikonStok(s.item), nada: menipis == null ? Nada.netral : Nada.peringatan),
        const SizedBox(width: Jarak.s12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(namaBarang(s.item), style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Jarak.s4),
            Wrap(spacing: Jarak.s8, runSpacing: Jarak.s4, children: [
              ChipPil('${ribuan(s.jumlah)} ${satuanBarang(s.item)}'),
              if (menipis != null) ChipPil(menipis, nada: Nada.peringatan, ikon: Icons.warning_rounded),
            ]),
            const SizedBox(height: Jarak.s8),
            BarisLaporan(label: 'Nilai', nilai: rupiah(s.nilai)),
          ]),
        ),
      ]),
    );
  }
}

class DetailAsetTetapPage extends StatefulWidget {
  const DetailAsetTetapPage({super.key, required this.aset, this.repo, this.foto});
  final AsetTetapTampil aset;
  final AccountingRepository? repo;
  final SumberFotoAset? foto;

  @override
  State<DetailAsetTetapPage> createState() => _DetailAsetTetapPageState();
}

class _DetailAsetTetapPageState extends State<DetailAsetTetapPage> {
  late final SumberFotoAset _foto = widget.foto ?? SumberFotoAset.instance;
  late Future<File?> _file = _foto.foto(widget.aset.id, widget.aset.idBeli);
  bool _semua = false;

  Future<void> _ambil(ImageSource sumber) async {
    final path = (await ImagePicker().pickImage(source: sumber, imageQuality: 60, maxWidth: 1600))?.path;
    if (path == null) return;
    final lama = await _file;
    if (lama != null) await FileImage(lama).evict();
    final baru = await _foto.simpan(widget.aset.id, widget.aset.idBeli, path);
    if (baru != null) await FileImage(baru).evict();
    if (mounted) {
      setState(() {
        _file = _foto.foto(widget.aset.id, widget.aset.idBeli);
      });
    }
  }

  Future<void> _bukaCatatan() async {
    final id = widget.aset.idBeli;
    final repo = widget.repo ?? AccountingRepository.instance;
    final c = id == null ? null : await repo.transactionById(id);
    if (c == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailCatatanPage(catatan: c, repo: widget.repo)));
    if (mounted) Navigator.pop(context); // nilai bisa berubah: kembali ke daftar yang dimuat ulang
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail aset')),
      body: FutureBuilder<File?>(
        future: _file,
        builder: (context, snap) => _isi(snap.data, snap.connectionState == ConnectionState.done),
      ),
    );
  }

  /// Tombol sumber foto (kamera / galeri).
  Widget _tombolFoto() => Wrap(spacing: Jarak.s8, runSpacing: Jarak.s8, children: [
        TombolKedua(
            label: 'Ambil foto',
            ikon: Icons.photo_camera_rounded,
            lebarPenuh: false,
            onPressed: () => _ambil(ImageSource.camera)),
        TombolKedua(
            label: 'Pilih dari galeri',
            ikon: Icons.photo_library_rounded,
            lebarPenuh: false,
            onPressed: () => _ambil(ImageSource.gallery)),
      ]);

  /// Tanpa foto: pilih sumber foto di lembar bawah.
  Future<void> _tambahFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // huruf besar: isi boleh lebih tinggi dari separuh layar, dan digulir
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Jarak.s16, 0, Jarak.s16, Jarak.s16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Tambah foto ${widget.aset.nama}', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Jarak.s12),
            TombolKedua(
                label: 'Ambil foto',
                ikon: Icons.photo_camera_rounded,
                onPressed: () => Navigator.pop(ctx, ImageSource.camera)),
            const SizedBox(height: Jarak.s8),
            TombolKedua(
                label: 'Pilih dari galeri',
                ikon: Icons.photo_library_rounded,
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ),
      ),
    );
    if (sumber != null) await _ambil(sumber);
  }

  Widget _isi(File? foto, bool dimuat) {
    final t = Theme.of(context).textTheme;
    final a = widget.aset;
    final riwayat = a.riwayat.reversed.toList();
    final tampil = _semua ? riwayat : riwayat.take(12).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, Jarak.s24),
      children: [
        // Ada foto: foto di atas. Tanpa foto: hanya baris ringkas di bawah informasi utama.
        if (foto != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Sudut.kartu),
            child: Image.file(foto, height: 220, width: double.infinity, fit: BoxFit.cover,
                semanticLabel: 'Foto ${a.nama}'),
          ),
          const SizedBox(height: Jarak.s12),
          _tombolFoto(),
          const SizedBox(height: Jarak.s24),
        ],
        Text(a.nama, style: t.headlineSmall),
        const SizedBox(height: Jarak.s8),
        Wrap(spacing: Jarak.s8, runSpacing: Jarak.s8, children: [
          ChipPil(teksSisaUmur(a), nada: a.sisaBulan == 0 ? Nada.peringatan : Nada.netral, ikon: ikonSisaUmur(a)),
          ChipPil('Siap pakai ${bulanPendek(a.siapPakai)}', ikon: Icons.event_rounded),
        ]),
        const SizedBox(height: Jarak.s16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
            child: Column(children: [
              BarisLaporan(label: 'Nilai perolehan', nilai: rupiah(a.hargaPerolehan)),
              BarisLaporan(label: 'Akumulasi penyusutan', nilai: rupiah(-a.akumulasi)),
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Warna.teksSekunder))),
                child: BarisLaporan(label: 'Nilai buku', nilai: rupiah(a.nilaiBuku), tebal: true, warnaNilai: Warna.primer),
              ),
              if (a.disusutkan) ...[
                BarisLaporan(label: 'Umur manfaat', nilai: '${a.umurBulan} bulan'),
                BarisLaporan(label: 'Sisa umur', nilai: '${a.sisaBulan} bulan'),
                BarisLaporan(label: 'Susut per bulan', nilai: rupiah(_susutBulanan(a))),
              ],
            ]),
          ),
        ),
        if (foto == null && dimuat) ...[
          const SizedBox(height: Jarak.s8),
          BarisTambahFoto(onTap: _tambahFoto),
        ],
        if (a.keterangan.isNotEmpty) ...[
          const SizedBox(height: Jarak.s12),
          Text(a.keterangan, style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        ],
        const SizedBox(height: Jarak.s24),
        const JudulSeksi('Riwayat penyusutan'),
        const SizedBox(height: Jarak.s4),
        Text(
            a.disusutkan
                ? 'Garis lurus tanpa nilai sisa, mulai bulan siap pakai. Dihitung otomatis, tidak perlu dicatat.'
                : 'Tanah tidak disusutkan; nilainya tetap sebesar harga perolehan.',
            style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
        const SizedBox(height: Jarak.s12),
        if (a.disusutkan && riwayat.isEmpty)
          Card(
            child: KosongRamah(
              ikon: Icons.event_available_rounded,
              judul: 'Belum mulai disusutkan',
              isi: 'Penyusutan pertama dihitung pada ${bulanPendek(a.siapPakai)}.',
            ),
          ),
        if (riwayat.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jarak.s16, vertical: Jarak.s8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _KepalaRiwayat(),
                for (final r in tampil) ...[
                  const Divider(),
                  BarisRiwayatSusut(baris: r),
                ],
              ]),
            ),
          ),
        if (riwayat.length > 12 && !_semua) ...[
          const SizedBox(height: Jarak.s12),
          TombolKedua(
            label: 'Tampilkan semua (${riwayat.length} bulan)',
            ikon: Icons.expand_more_rounded,
            onPressed: () => setState(() => _semua = true),
          ),
        ],
        if (a.idBeli != null) ...[
          const SizedBox(height: Jarak.s24),
          TombolKedua(label: 'Lihat catatan pembelian', ikon: Icons.receipt_long_rounded, onPressed: _bukaCatatan),
        ],
      ],
    );
  }

  int _susutBulanan(AsetTetapTampil a) =>
      a.riwayat.isNotEmpty ? a.riwayat.first.susut : roundHalfAwayFromZero(a.hargaPerolehan, a.umurBulan!);
}

/// Baris ringkas aset tanpa foto: ikon kecil + "Tambah foto", tinggi sentuh >= 48dp.
class BarisTambahFoto extends StatelessWidget {
  const BarisTambahFoto({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sudut.kecil),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tinggiSentuh),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s8),
            child: Row(children: [
              Icon(Icons.add_a_photo_rounded, size: 20 * skalaIkon(context), color: Warna.primer),
              const SizedBox(width: Jarak.s8),
              Expanded(
                child: Text('Tambah foto', style: t.titleSmall!.copyWith(color: Warna.primer, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right_rounded, size: 24 * skalaIkon(context), color: Warna.primer),
            ]),
          ),
        ),
      ),
    );
  }
}

class _KepalaRiwayat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).textTheme.labelMedium!.copyWith(color: Warna.teksSekunder);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jarak.s8),
      child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: Jarak.s8, children: [
        Text('Bulan', style: g),
        Text('Nilai buku sesudah susut', style: g),
      ]),
    );
  }
}

/// Satu bulan penyusutan: bulan dan nilai buku sesudahnya (rata kanan), susutnya di bawah.
class BarisRiwayatSusut extends StatelessWidget {
  const BarisRiwayatSusut({super.key, required this.baris});
  final BarisSusut baris;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = baris;
    return Semantics(
      label: '${bulanPendek(r.bulan)}: susut ${rupiah(r.susut)}, nilai buku ${rupiah(r.nilaiBuku)}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BarisLaporan(label: bulanPendek(r.bulan), nilai: rupiah(r.nilaiBuku), tebal: true),
        Padding(
          padding: const EdgeInsets.only(bottom: Jarak.s4),
          child: Text('Susut ${rupiah(-r.susut)}', style: gayaAngka(t.bodySmall!.copyWith(color: Warna.teksSekunder))),
        ),
      ]),
    );
  }
}
