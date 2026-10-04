// Tab Lainnya (UI-PLAN.md 3.6): cadangan (ekspor, pulihkan, tanggal ekspor
// terakhir), tutup buku, ekspor CSV, nama usaha, inventaris, zona bahaya.
// Pengganti settings_page.dart. Layanan platform (bagikan file, pilih file,
// reset) lewat [LayananLainnya] agar alurnya bisa dites.
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart' show XTypeGroup, getSaveLocation, openFile;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as pathlib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, ShareResultStatus, XFile;
import 'package:shared_preferences/shared_preferences.dart';

import 'accounting/repository.dart';
import 'database/backup.dart';
import 'database/database_helper.dart';
import 'inventaris_data.dart';
import 'list_asset_page.dart';
import 'splash_page.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

/// Kunci SharedPreferences: waktu ekspor cadangan terakhir (ISO-8601).
const kunciCadanganTerakhir = 'cadangan_terakhir';

/// Lewat batas ini (hari) tanpa ekspor, Lainnya menampilkan pengingat.
const batasHariCadangan = 7;

bool get _seluler => Platform.isAndroid || Platform.isIOS;

/// Bagikan/simpan file [path] bernama [nama]. null = dibatalkan pengguna.
Future<String?> _bagikanAtauSimpan(String path, String nama, String mime, String ekstensi) async {
  if (_seluler) {
    final res = await Share.shareXFiles([XFile(path, mimeType: mime)], subject: nama);
    return res.status == ShareResultStatus.dismissed ? null : nama;
  }
  final loc = await getSaveLocation(
    suggestedName: nama,
    acceptedTypeGroups: [XTypeGroup(label: nama, extensions: [ekstensi])],
  );
  if (loc == null) return null;
  await File(path).copy(loc.path);
  return loc.path;
}

/// Ekspor salinan file DB: Android lewat lembar bagikan (Drive, WhatsApp, Files),
/// desktop lewat dialog simpan. Mengembalikan nama/lokasi tujuan, null bila dibatalkan.
Future<String?> eksporCadanganAplikasi() async {
  final nama = backupFileName(DateTime.now());
  final tmp = await BackupService.instance.exportTo(pathlib.join((await getTemporaryDirectory()).path, nama));
  return _bagikanAtauSimpan(tmp, nama, 'application/octet-stream', 'db');
}

Future<({String path, String nama})?> pilihFileCadanganAplikasi() async {
  final file = await openFile(
    // Android memfilter dengan MIME; file .db tidak punya MIME baku, jadi semua file ditampilkan.
    acceptedTypeGroups: _seluler ? const [] : const [XTypeGroup(label: 'Cadangan SiKaya', extensions: ['db'])],
  );
  return file == null ? null : (path: file.path, nama: file.name);
}

Future<String?> eksporCsvAplikasi(String csv, String nama) async {
  final tmp = File(pathlib.join((await getTemporaryDirectory()).path, nama));
  await tmp.writeAsString(csv);
  return _bagikanAtauSimpan(tmp.path, nama, 'text/csv', 'csv');
}

void _mulaiUlangAplikasi(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashPage()), (_) => false);

class LayananLainnya {
  const LayananLainnya({
    this.eksporCadangan = eksporCadanganAplikasi,
    this.pilihFileCadangan = pilihFileCadanganAplikasi,
    this.periksaCadangan,
    this.ringkasanSekarang,
    this.pulihkan,
    this.eksporCsv = eksporCsvAplikasi,
    this.hapusSemua,
    this.mulaiUlang = _mulaiUlangAplikasi,
  });
  final Future<String?> Function() eksporCadangan;
  final Future<({String path, String nama})?> Function() pilihFileCadangan;
  final Future<BackupSummary> Function(String path)? periksaCadangan;
  final Future<BackupSummary> Function()? ringkasanSekarang;
  final Future<RestoreResult> Function(String path)? pulihkan;
  final Future<String?> Function(String csv, String namaFile) eksporCsv;

  /// Salin DB sebagai cadangan lalu hapus; mengembalikan path cadangan.
  final Future<String> Function()? hapusSemua;

  /// Muat ulang aplikasi dari awal (sesudah pulihkan/hapus semua).
  final void Function(BuildContext context) mulaiUlang;

  Future<BackupSummary> periksa(String p) => (periksaCadangan ?? BackupService.instance.inspect)(p);
  Future<BackupSummary> sekarang() => (ringkasanSekarang ?? BackupService.instance.currentSummary)();
  Future<RestoreResult> pulihkanDari(String p) => (pulihkan ?? BackupService.instance.restoreFrom)(p);
  Future<String> hapus() => (hapusSemua ?? DatabaseHelper.instance.resetDatabase)();
}

/// CSV daftar catatan (dibuka di Excel). Kolom sama dengan versi sebelumnya.
String buatCsvCatatan(List<List<Object?>> baris) => const ListToCsvConverter().convert([
      ['Tanggal', 'Tipe', 'Kategori', 'Nominal', 'Deskripsi'],
      ...baris,
    ]);

/// "4 Oktober 2026 (hari ini)" / "(3 hari lalu)".
String teksCadanganTerakhir(DateTime t, DateTime hariIni) {
  final hari = DateTime(hariIni.year, hariIni.month, hariIni.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  final berapa = hari <= 0 ? 'hari ini' : (hari == 1 ? 'kemarin' : '$hari hari lalu');
  return '${tanggalPanjang(isoTanggal(t))} ($berapa)';
}

class LainnyaPage extends StatefulWidget {
  const LainnyaPage({super.key, this.repo, this.layanan = const LayananLainnya(), this.inventaris, this.hariIni});
  final AccountingRepository? repo;
  final LayananLainnya layanan;
  final SumberInventaris? inventaris;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  @override
  State<LainnyaPage> createState() => _LainnyaPageState();
}

class _LainnyaPageState extends State<LainnyaPage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;
  LayananLainnya get _l => widget.layanan;
  DateTime get _hariIni => widget.hariIni ?? DateTime.now();

  String _nama = '';
  DateTime? _cadanganTerakhir;
  DateTime? _ditutupSampai;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  /// Gagal membaca pengaturan/DB tidak menghalangi tampilan menu.
  Future<void> _muat() async {
    String? nama, cadangan;
    DateTime? kunci;
    try {
      final prefs = await SharedPreferences.getInstance();
      nama = prefs.getString('owner_name');
      cadangan = prefs.getString(kunciCadanganTerakhir);
      kunci = await _repo.lockedUntil();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _nama = nama ?? 'Usaha Saya';
      _cadanganTerakhir = DateTime.tryParse(cadangan ?? '');
      _ditutupSampai = kunci;
    });
  }

  Future<void> _pesan(String judul, String isi, {bool gagal = false}) async {
    if (mounted) await tampilkanPesan(context, judul: judul, isi: isi, gagal: gagal);
  }

  Future<T?> _jalankan<T>(Future<T> Function() aksi) async {
    setState(() => _sibuk = true);
    try {
      return await aksi();
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  // --- Cadangan ---

  /// true bila tersimpan/terbagi; false bila dibatalkan atau gagal.
  Future<bool> _eksporCadangan({bool beriTahu = true}) async {
    try {
      final tujuan = await _jalankan(_l.eksporCadangan);
      if (tujuan == null) return false;
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kunciCadanganTerakhir, (widget.hariIni ?? now).toIso8601String());
      if (mounted) setState(() => _cadanganTerakhir = widget.hariIni ?? now);
      if (beriTahu) {
        await _pesan('Cadangan tersimpan',
            '$tujuan\n\nSimpan file ini di tempat lain (Google Drive, WhatsApp, flashdisk). '
            'Bila HP hilang atau rusak, pulihkan lewat tombol "Pulihkan cadangan".');
      }
      return true;
    } catch (e) {
      await _pesan('Cadangan gagal dibuat', 'Data tidak diubah.\n$e', gagal: true);
      return false;
    }
  }

  String _ringkas(BackupSummary s) =>
      '${s.transaksi} catatan, ${s.asetTetap} aset tetap, ${s.inventaris} barang inventaris'
      '${s.tanggalAwal == null ? '' : '\nTanggal catatan: ${s.tanggalAwal} s.d. ${s.tanggalAkhir}'}'
      '${s.ditutupSampai == null ? '' : '\nDitutup buku sampai: ${s.ditutupSampai}'}';

  Future<void> _pulihkan() async {
    final file = await _l.pilihFileCadangan();
    if (file == null) return;
    final BackupSummary isi, sekarang;
    try {
      isi = await _l.periksa(file.path);
      sekarang = await _l.sekarang();
    } on BackupInvalidException catch (e) {
      await _pesan('File ditolak', '${e.pesan}\n\nData saat ini tidak diubah.', gagal: true);
      return;
    }
    if (!mounted) return;
    final ya = await tanyaKonfirmasi(
      context,
      judul: 'Pulihkan cadangan ini?',
      isi: 'File: ${file.nama}\n\n'
          'Isi cadangan:\n${_ringkas(isi)}\n\n'
          'Data saat ini akan DIGANTI seluruhnya:\n${_ringkas(sekarang)}\n\n'
          '${peringatanPulihkan(isi, sekarang)}\n\n'
          'Sebelum diganti, data saat ini disalin otomatis sebagai cadangan di folder database aplikasi.',
      aksi: 'Pulihkan',
      ikonAksi: Icons.restore_rounded,
      bahaya: true,
    );
    if (!ya) return;
    final RestoreResult r;
    try {
      r = (await _jalankan(() => _l.pulihkanDari(file.path)))!;
    } on BackupInvalidException catch (e) {
      await _pesan('File ditolak', '${e.pesan}\n\nData saat ini tidak diubah.', gagal: true);
      return;
    } catch (e) {
      await _pesan('Pemulihan gagal', '$e', gagal: true);
      return;
    }
    await _pesan('Cadangan dipulihkan', '${_ringkas(r.dipulihkan)}\n\nData sebelumnya disimpan di:\n${r.cadanganOtomatis}');
    if (mounted) _l.mulaiUlang(context);
  }

  // --- Tutup buku ---

  String _tgl(DateTime t) => tanggalPanjang(isoTanggal(t));

  /// Sebelum tutup buku: tawarkan ekspor cadangan. false = tutup buku dibatalkan.
  Future<bool> _tawarkanCadangan() async {
    while (true) {
      if (!mounted) return false;
      final pilih = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ekspor cadangan dulu?'),
          content: const SingleChildScrollView(
            child: Text('Tutup buku mengunci catatan untuk selamanya.\n\n'
                'Aplikasi memang menyalin data otomatis, tetapi salinan itu ada di HP ini: ikut hilang bila '
                'aplikasi dihapus atau HP rusak/hilang. Tanpa cadangan di tempat lain, data tidak bisa dipulihkan.'),
          ),
          // Tombol di luar isi yang digulir: selalu terlihat, bertumpuk bila tidak muat.
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            TombolKedua(label: 'Batal', ikon: Icons.close_rounded, lebarPenuh: false, onPressed: () => Navigator.pop(ctx)),
            TombolKedua(
                label: 'Lewati', ikon: Icons.skip_next_rounded, lebarPenuh: false, onPressed: () => Navigator.pop(ctx, false)),
            TombolUtama(
                label: 'Ekspor cadangan dulu',
                ikon: Icons.save_alt_rounded,
                lebarPenuh: false,
                onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      );
      if (pilih == null) return false;
      if (!pilih) return true;
      if (await _eksporCadangan(beriTahu: false)) return true;
      // Dibatalkan/gagal: tanya lagi.
    }
  }

  /// Tutup buku non-destruktif (AccountingRepository.closeBook). Teks dialog
  /// menjelaskan persis apa yang dilakukan closeBook.
  Future<void> _tutupBuku() async {
    final lock = await _repo.lockedUntil();
    final now = _hariIni;
    final today = DateTime(now.year, now.month, now.day);
    if (!mounted) return;
    if (lock != null && !today.isAfter(lock)) {
      await _pesan('Tutup buku', 'Catatan sampai ${_tgl(lock)} sudah ditutup buku.');
      return;
    }
    var awal = DateTime(now.year, now.month, 0); // akhir bulan lalu
    if (lock != null && !awal.isAfter(lock)) awal = today;
    final until = await showDatePicker(
      context: context,
      helpText: 'Tutup buku sampai tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      initialDate: awal,
      firstDate: lock == null ? DateTime(2000) : lock.add(const Duration(days: 1)),
      lastDate: today,
    );
    if (until == null) return;

    final ClosingPreview p;
    try {
      p = await _repo.previewClosing(until, today: today);
    } on ClosingRejectedException catch (e) {
      await _pesan('Belum bisa tutup buku', e.pesan, gagal: true);
      return;
    }
    if (!await _tawarkanCadangan() || !mounted) return;
    final dari = p.from == null ? 'awal pencatatan' : _tgl(p.from!);
    final laba = p.report.labaBersih;
    final ya = await tanyaKonfirmasi(
      context,
      judul: 'Tutup buku sampai ${_tgl(p.until)}?',
      isi: 'Periode $dari s.d. ${_tgl(p.until)}.\n\n'
          '1. Data disalin dulu sebagai cadangan di folder database aplikasi.\n'
          '2. ${laba >= 0 ? 'Untung' : 'Rugi'} periode ini ${rupiah(laba.abs())} dicatat sebagai entri '
          'Tutup Buku ke Saldo Laba.\n'
          '3. Semua catatan bertanggal sampai ${_tgl(p.until)} dikunci: tidak bisa ditambah, diubah, atau dihapus. '
          'Koreksi dicatat lewat retur bertanggal sesudahnya.\n'
          '4. Tidak ada catatan yang dihapus. Total aset tetap ${rupiah(p.report.totalAset)}.\n\n'
          'Kunci ini tidak bisa dibuka dari aplikasi.',
      aksi: 'Tutup buku',
      ikonAksi: Icons.lock_rounded,
      bahaya: true,
    );
    if (!ya) return;
    try {
      final r = (await _jalankan(() => _repo.closeBook(until, today: today)))!;
      if (mounted) setState(() => _ditutupSampai = r.preview.until);
      await _pesan('Tutup buku selesai',
          'Catatan sampai ${_tgl(r.preview.until)} dikunci. ${laba >= 0 ? 'Untung' : 'Rugi'} '
          '${rupiah(r.preview.report.labaBersih.abs())} dicatat ke Saldo Laba.\n\nCadangan:\n${r.backupPath}');
    } on ClosingRejectedException catch (e) {
      await _pesan('Belum bisa tutup buku', e.pesan, gagal: true);
    } catch (e) {
      await _pesan('Tutup buku gagal', 'Data pembukuan tidak diubah.\n$e', gagal: true);
    }
  }

  // --- CSV, nama usaha, hapus semua ---

  Future<void> _eksporCsv() async {
    try {
      final trans = await _repo.transactions();
      if (trans.isEmpty) {
        await _pesan('Belum ada catatan', 'Belum ada catatan untuk diekspor.');
        return;
      }
      final csv = buatCsvCatatan([
        for (final t in trans) [t.date, t.txType.code, t.category, t.amount, t.description],
      ]);
      final nama = 'Catatan_SiKaya_${DateFormat('yyyyMMdd').format(_hariIni)}.csv';
      final tujuan = await _jalankan(() => _l.eksporCsv(csv, nama));
      if (tujuan == null) return;
      await _pesan('CSV tersimpan',
          '$tujuan\n\nFile ini untuk dibuka di Excel; bukan cadangan dan tidak bisa dipulihkan.');
    } catch (e) {
      await _pesan('CSV gagal dibuat', '$e', gagal: true);
    }
  }

  Future<void> _ubahNama() async {
    final baru = await showDialog<String>(context: context, builder: (_) => _DialogNama(awal: _nama));
    if (baru == null || baru.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', baru);
    if (mounted) setState(() => _nama = baru);
  }

  Future<void> _hapusSemua() async {
    final ya = await tanyaKonfirmasi(
      context,
      judul: 'Hapus semua data?',
      isi: 'Semua catatan, aset, inventaris, data tutup buku, nama usaha, dan pengaturan dihapus dari aplikasi.\n\n'
          'Sebelum dihapus, data disalin sebagai cadangan di folder database aplikasi. '
          'Salinan ini ikut terhapus bila aplikasi di-uninstall, jadi ekspor cadangan dulu bila masih perlu.',
      aksi: 'Hapus semuanya',
      ikonAksi: Icons.delete_forever_rounded,
      bahaya: true,
    );
    if (!ya || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cadangan = (await _jalankan(_l.hapus))!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      messenger.showSnackBar(SnackBar(content: Text('Data dihapus. Cadangan: $cadangan')));
      if (mounted) _l.mulaiUlang(context);
    } catch (e) {
      await _pesan('Gagal menghapus', '$e', gagal: true);
    }
  }

  // --- Tampilan ---

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final terakhir = _cadanganTerakhir;
    final lama = terakhir == null ||
        DateTime(_hariIni.year, _hariIni.month, _hariIni.day).difference(terakhir).inDays >= batasHariCadangan;
    const jarak = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(
            label: _sibuk ? 'Mohon tunggu...' : 'Ekspor cadangan',
            ikon: Icons.save_alt_rounded,
            onPressed: _sibuk ? null : _eksporCadangan,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, Jarak.s24),
        children: [
          // Profil usaha (gaya Pengaturan lama): logo, nama, peran.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Jarak.s16),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(Jarak.s8),
                  decoration: const BoxDecoration(color: Warna.primerMuda, shape: BoxShape.circle),
                  child: ClipOval(child: Image.asset('assets/icon_ayam.png', fit: BoxFit.contain)),
                ),
                const SizedBox(width: Jarak.s16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_nama, style: t.titleMedium),
                    const SizedBox(height: Jarak.s4),
                    const ChipPil('Pemilik peternakan', nada: Nada.peringatan, ikon: Icons.verified_rounded),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: Jarak.s24),
          const JudulSeksi('Cadangan & Pengaturan'),
          jarak,
          if (lama)
            BannerPeringatan(
              judul: terakhir == null ? 'Belum pernah membuat cadangan' : 'Sudah lama tidak membuat cadangan',
              isi: 'Data hanya tersimpan di HP ini. Tekan "Ekspor cadangan" di bawah, lalu simpan filenya '
                  'di Google Drive atau kirim ke WhatsApp Anda sendiri. Lakukan seminggu sekali.',
            ),
          if (lama) jarak,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Jarak.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  UbinIkon(lama ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      nada: lama ? Nada.peringatan : Nada.sukses),
                  const SizedBox(width: Jarak.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cadangan terakhir', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      Text(terakhir == null ? 'Belum pernah' : teksCadanganTerakhir(terakhir, _hariIni),
                          style: t.bodyLarge!.copyWith(color: lama ? Warna.peringatan : Warna.sukses)),
                    ]),
                  ),
                ]),
                const SizedBox(height: Jarak.s12),
                TombolKedua(
                    label: 'Pulihkan cadangan', ikon: Icons.restore_rounded, onPressed: _sibuk ? null : _pulihkan),
              ]),
            ),
          ),
          jarak,
          _Grup(children: [
            _Menu(
              ikon: Icons.lock_clock_rounded,
              judul: 'Tutup buku',
              keterangan: 'Kunci catatan sampai tanggal tertentu dan pindahkan untung ke saldo laba. '
                  '${_ditutupSampai == null ? 'Belum pernah ditutup.' : 'Sudah ditutup sampai ${_tgl(_ditutupSampai!)}.'}',
              onTap: _sibuk ? null : _tutupBuku,
            ),
            _Menu(
              ikon: Icons.table_view_rounded,
              nada: Nada.sukses,
              judul: 'Ekspor CSV (untuk Excel)',
              keterangan: 'Daftar catatan untuk dibuka di Excel. Bukan cadangan; tidak bisa dipulihkan.',
              onTap: _sibuk ? null : _eksporCsv,
            ),
            _Menu(
              ikon: Icons.storefront_rounded,
              nada: Nada.peringatan,
              judul: 'Nama usaha',
              keterangan: '$_nama\nKetuk untuk mengubah.',
              onTap: _ubahNama,
            ),
          ]),
          const SizedBox(height: Jarak.s24),
          const JudulSeksi('Inventaris'),
          jarak,
          _Grup(children: [
            _Menu(
              ikon: Icons.inventory_2_rounded,
              judul: 'Daftar inventaris',
              keterangan: 'Ternak, barang, dan peralatan yang dimiliki (tidak masuk laporan keuangan).',
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ListAssetPage(sumber: widget.inventaris))),
            ),
          ]),
          const SizedBox(height: Jarak.s24),
          const JudulSeksi('Zona bahaya', warna: Warna.error),
          jarak,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Jarak.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const UbinIkon(Icons.delete_forever_rounded, nada: Nada.error),
                  const SizedBox(width: Jarak.s12),
                  Expanded(child: Text('Menghapus semua catatan dan pengaturan di HP ini.', style: t.bodyLarge)),
                ]),
                jarak,
                TombolBahaya(
                    label: 'Hapus semua data',
                    ikon: Icons.delete_forever_rounded,
                    onPressed: _sibuk ? null : _hapusSemua),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog ubah nama; memiliki controller sendiri (dibuang saat dialog benar-benar hilang).
class _DialogNama extends StatefulWidget {
  const _DialogNama({required this.awal});
  final String awal;

  @override
  State<_DialogNama> createState() => _DialogNamaState();
}

class _DialogNamaState extends State<_DialogNama> {
  late final _c = TextEditingController(text: widget.awal);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ubah nama usaha'),
        content: SingleChildScrollView(
          child: LabelIsian(
            label: 'Nama peternakan / pemilik',
            child: TextField(controller: _c, autofocus: true, textCapitalization: TextCapitalization.words),
          ),
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TombolKedua(label: 'Batal', ikon: Icons.close_rounded, lebarPenuh: false, onPressed: () => Navigator.pop(context)),
          TombolUtama(
              label: 'Simpan',
              ikon: Icons.save_rounded,
              lebarPenuh: false,
              onPressed: () => Navigator.pop(context, _c.text.trim())),
        ],
      );
}

/// Beberapa menu dalam satu kartu, dipisah garis tipis.
class _Grup extends StatelessWidget {
  const _Grup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 72),
            children[i],
          ],
        ]),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({required this.ikon, required this.judul, required this.keterangan, this.onTap, this.nada = Nada.netral});
  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback? onTap;
  final Nada nada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(Jarak.s16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            UbinIkon(ikon, nada: nada),
            const SizedBox(width: Jarak.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Jarak.s4),
                Text(keterangan, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(top: Jarak.s8),
              child: Icon(Icons.chevron_right_rounded, color: Warna.teksSekunder),
            ),
          ]),
        ),
      ),
    );
  }
}
