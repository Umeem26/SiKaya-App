import 'dart:io';
import 'package:file_selector/file_selector.dart' show XTypeGroup, getSaveLocation, openFile;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as pathlib;
import 'package:share_plus/share_plus.dart' show Share, ShareResultStatus, XFile;
import 'database/backup.dart';
import 'database/database_helper.dart';
import 'accounting/repository.dart';
import 'accounting/tx_form_spec.dart' show formatRupiah;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'splash_page.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color polbanBlue = const Color(0xFF1E549F);
  final Color polbanOrange = const Color(0xFFFA9C1B);
  String _ownerName = "Administrator";

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  void _loadOwnerName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _ownerName = prefs.getString('owner_name') ?? "Administrator");
  }

  Future<void> _backupData() async {
     try {
      final trans = await AccountingRepository.instance.transactions();
      if (!mounted) return;
      if (trans.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data kosong."))); return; }
      List<List<dynamic>> rows = [];
      rows.add(["Tanggal", "Tipe", "Kategori", "Nominal", "Deskripsi"]);
      for (var t in trans) { rows.add([t.date, t.txType.code, t.category, t.amount, t.description]); }
      String csvData = const ListToCsvConverter().convert(rows);
      String? filePath;
      String fileName = "Backup_Ternak_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
      if (Platform.isWindows) { final dir = await getDownloadsDirectory(); if (dir != null) filePath = "${dir.path}\\$fileName"; } 
      else { final dir = await getExternalStorageDirectory(); if (dir != null) filePath = "${dir.path}/$fileName"; }
      if (filePath != null) { final file = File(filePath); await file.writeAsString(csvData); _showDialog("Backup Berhasil", "File di:\n$filePath"); }
    } catch (e) { _showDialog("Gagal", e.toString()); }
  }
  void _showDialog(String t, String c) {
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Text(t), content: Text(c), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))]));
  }

  String _tgl(DateTime t) => DateFormat('dd-MM-yyyy').format(t);

  bool get _seluler => Platform.isAndroid || Platform.isIOS;

  /// Ekspor salinan file DB: Android lewat share sheet (Drive, WhatsApp, Files),
  /// desktop lewat dialog simpan. true bila tersimpan/terbagi; false bila dibatalkan/gagal.
  Future<bool> _eksporCadangan({bool beriTahu = true}) async {
    final nama = backupFileName(DateTime.now());
    try {
      final String tujuan;
      if (_seluler) {
        final path = await BackupService.instance.exportTo(pathlib.join((await getTemporaryDirectory()).path, nama));
        final res = await Share.shareXFiles([XFile(path, mimeType: 'application/octet-stream')], subject: nama);
        if (res.status == ShareResultStatus.dismissed) return false;
        tujuan = nama;
      } else {
        final loc = await getSaveLocation(
          suggestedName: nama,
          acceptedTypeGroups: const [XTypeGroup(label: 'Cadangan SiKaya', extensions: ['db'])],
        );
        if (loc == null) return false;
        tujuan = await BackupService.instance.exportTo(loc.path);
      }
      if (beriTahu) {
        _showDialog("Cadangan Tersimpan",
            "$tujuan\n\nSimpan file ini di tempat lain (Google Drive, WhatsApp, flashdisk). "
            "Pulihkan lewat menu Pulihkan Cadangan.");
      }
      return true;
    } catch (e) {
      _showDialog("Ekspor Gagal", "Data tidak diubah.\n$e");
      return false;
    }
  }

  String _ringkas(BackupSummary s) =>
      "${s.transaksi} transaksi, ${s.asetTetap} aset tetap, ${s.inventaris} barang inventaris"
      "${s.tanggalAwal == null ? '' : '\nTanggal transaksi: ${s.tanggalAwal} s.d. ${s.tanggalAkhir}'}"
      "${s.ditutupSampai == null ? '' : '\nDitutup buku sampai: ${s.ditutupSampai}'}";

  /// Pilih file, periksa, tampilkan ringkasan, lalu ganti data saat ini.
  Future<void> _pulihkanCadangan() async {
    final svc = BackupService.instance;
    final file = await openFile(
      // Android memfilter dengan MIME; file .db tidak punya MIME baku, jadi semua file ditampilkan.
      acceptedTypeGroups: _seluler ? const [] : const [XTypeGroup(label: 'Cadangan SiKaya', extensions: ['db'])],
    );
    if (file == null) return;
    final BackupSummary isi, sekarang;
    try {
      isi = await svc.inspect(file.path);
      sekarang = await svc.currentSummary();
    } on BackupInvalidException catch (e) {
      _showDialog("File Ditolak", "${e.pesan}\n\nData saat ini tidak diubah.");
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pulihkan Cadangan?"),
        content: SingleChildScrollView(
          child: Text(
            "File: ${file.name}\n\n"
            "Isi cadangan:\n${_ringkas(isi)}\n\n"
            "Data saat ini akan DIGANTI seluruhnya:\n${_ringkas(sekarang)}\n\n"
            "${peringatanPulihkan(isi, sekarang)}\n\n"
            "Sebelum diganti, data saat ini disalin otomatis sebagai cadangan di folder database aplikasi.",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Pulihkan")),
        ],
      ),
    );
    if (ok != true) return;
    final RestoreResult r;
    try {
      r = await svc.restoreFrom(file.path);
    } on BackupInvalidException catch (e) {
      _showDialog("File Ditolak", "${e.pesan}\n\nData saat ini tidak diubah.");
      return;
    } catch (e) {
      _showDialog("Pemulihan Gagal", "$e");
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cadangan Dipulihkan"),
        content: Text("${_ringkas(r.dipulihkan)}\n\nData sebelumnya disimpan di:\n${r.cadanganOtomatis}"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
    if (!mounted) return;
    // Muat ulang semua halaman dengan data baru.
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SplashPage()), (route) => false);
  }

  /// Sebelum tutup buku: tawarkan ekspor cadangan. false = pengguna membatalkan tutup buku.
  Future<bool> _tawarkanCadangan() async {
    while (true) {
      if (!mounted) return false;
      final pilih = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Ekspor Cadangan Dulu?"),
          content: const SingleChildScrollView(
            child: Text(
              "Tutup buku mengunci periode secara permanen.\n\n"
              "Aplikasi memang menyalin database otomatis, tetapi salinan itu ada di folder aplikasi: "
              "ikut hilang bila aplikasi di-uninstall, datanya dihapus, atau HP rusak/hilang. "
              "Tanpa cadangan di tempat lain, data tidak bisa dipulihkan.",
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Lewati")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ekspor Cadangan")),
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
    final repo = AccountingRepository.instance;
    final lock = await repo.lockedUntil();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!mounted) return;
    if (lock != null && !today.isAfter(lock)) {
      _showDialog("Tutup Buku", "Periode sampai ${_tgl(lock)} sudah ditutup buku.");
      return;
    }
    var awal = DateTime(now.year, now.month, 0); // akhir bulan lalu
    if (lock != null && !awal.isAfter(lock)) awal = today;
    final until = await showDatePicker(
      context: context,
      helpText: "TUTUP BUKU SAMPAI TANGGAL",
      initialDate: awal,
      firstDate: lock == null ? DateTime(2000) : lock.add(const Duration(days: 1)),
      lastDate: today,
    );
    if (until == null) return;

    final ClosingPreview p;
    try {
      p = await repo.previewClosing(until);
    } on ClosingRejectedException catch (e) {
      _showDialog("Tidak Bisa Tutup Buku", e.pesan);
      return;
    }
    if (!await _tawarkanCadangan()) return;
    if (!mounted) return;
    final dari = p.from == null ? "awal pencatatan" : _tgl(p.from!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tutup Buku?"),
        content: SingleChildScrollView(
          child: Text(
            "Periode $dari s.d. ${_tgl(p.until)}.\n\n"
            "1. File database disalin dulu sebagai cadangan di folder yang sama dengan database aplikasi.\n"
            "2. Laba (rugi) periode ini ${formatRupiah(p.report.labaBersih)} dicatat sebagai entri Tutup Buku ke Saldo Laba.\n"
            "3. Semua transaksi bertanggal sampai ${_tgl(p.until)} dikunci: tidak bisa ditambah, diubah, atau dihapus. "
            "Koreksi dicatat lewat retur/transaksi pembalik bertanggal sesudahnya.\n"
            "4. Tidak ada transaksi yang dihapus. Total aset tidak berubah: ${formatRupiah(p.report.totalAset)}.\n\n"
            "Kunci ini tidak bisa dibuka dari aplikasi.",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Tutup Buku")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await repo.closeBook(until);
      _showDialog("Tutup Buku Selesai",
          "Periode sampai ${_tgl(r.preview.until)} dikunci. Laba (rugi) ${formatRupiah(r.preview.report.labaBersih)} "
          "dicatat ke Saldo Laba.\n\nCadangan:\n${r.backupPath}");
    } on ClosingRejectedException catch (e) {
      _showDialog("Tidak Bisa Tutup Buku", e.pesan);
    } catch (e) {
      _showDialog("Tutup Buku Gagal", "Data pembukuan tidak diubah.\n$e");
    }
  }

  Future<void> _resetAplikasi() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Semua Data?"),
        content: const Text(
          "Semua transaksi, aset, data tutup buku, nama peternakan, dan pengaturan dihapus dari aplikasi.\n\n"
          "Sebelum dihapus, file database disalin sebagai cadangan di folder yang sama dengan database aplikasi. "
          "Di Android, cadangan ini ikut terhapus bila aplikasi di-uninstall.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus Semuanya", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final backup = await DatabaseHelper.instance.resetDatabase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Data dihapus. Cadangan: $backup")));
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SplashPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: polbanBlue, foregroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFILE CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.blueGrey.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Row(
                children: [
                  CircleAvatar(radius: 35, backgroundColor: polbanBlue.withValues(alpha: 0.1), child: Icon(Icons.person, size: 40, color: polbanBlue)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_ownerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 5),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: polbanOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text("Pemilik Peternakan", style: TextStyle(color: polbanOrange, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 35),

            // MENU ITEMS
            _header("Manajemen Data"),
            _menuCard([
              _tile(Icons.save_alt_rounded, "Ekspor Cadangan", "Salinan lengkap data (bisa dipulihkan)", Colors.green, _eksporCadangan),
              const Divider(height: 1),
              _tile(Icons.restore_rounded, "Pulihkan Cadangan", "Ganti data dengan file cadangan", Colors.orange, _pulihkanCadangan),
              const Divider(height: 1),
              _tile(Icons.download_rounded, "Ekspor CSV (untuk dibuka di Excel)", "Bukan cadangan; tidak bisa dipulihkan", Colors.green, _backupData),
              const Divider(height: 1),
              _tile(Icons.history_edu_rounded, "Tutup Buku", "Kunci periode & catat laba ke Saldo Laba", polbanBlue, _tutupBuku),
            ]),
            
            const SizedBox(height: 25),
            _header("Zona Bahaya"),
            _menuCard([
              _tile(Icons.delete_forever_rounded, "Reset Aplikasi", "Hapus semua data (cadangan dibuat dulu)", Colors.redAccent, _resetAplikasi),
            ]),
            
            const SizedBox(height: 50),
            Center(
              child: Column(
                children: [
                  Icon(Icons.code, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("Versi 1.1.0 (Polban Edition)", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 5), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey[800])));
  
  Widget _menuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(children: children),
    );
  }

  Widget _tile(IconData i, String t, String s, Color c, VoidCallback tap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: c, size: 22)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: tap,
    );
  }
}