// Cadangan yang bisa diakses pengguna: ekspor zip (file DB + foto aset tetap dan
// inventaris + manifest.json), periksa file cadangan, dan pulihkan. Pemulihan juga
// menerima file .db lama (tanpa foto). Tanpa UI: lembar bagikan dan pemilih file
// ada di lainnya_page.dart, sehingga alur ini bisa dites dengan sqflite_ffi.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../accounting/engine.dart';
import '../accounting/repository.dart';
import '../transaction_model.dart';
import 'database_helper.dart';
import 'schema.dart';

/// Skema tertua yang datanya bisa dipulihkan. v1 = data sebelum Fase 1, tabelnya
/// dibuat ulang saat migrasi (PLAN-FASE1 bagian 1), jadi isinya akan hilang.
const int minRestorableVersion = 2;

/// Tabel inti yang wajib ada di file cadangan.
const coreTables = {'transactions', 'fixed_assets', 'period_closings', 'assets'};

String _stempel(DateTime t) => DateFormat('yyyyMMdd_HHmmss').format(t);

/// `SiKaya_cadangan_v<skema>_<yyyyMMdd_HHmmss>.db` (format lama, tanpa foto).
String backupFileName(DateTime now) => 'SiKaya_cadangan_v${dbVersion}_${_stempel(now)}.db';

/// `SiKaya_cadangan_v<skema>_<yyyyMMdd_HHmmss>.zip` (DB + foto + manifest).
String backupZipFileName(DateTime now) => 'SiKaya_cadangan_v${dbVersion}_${_stempel(now)}.zip';

/// Isi zip cadangan. Nama lain apa pun di dalam zip membuat cadangan ditolak.
const formatCadangan = 'sikaya-cadangan';
const versiFormatCadangan = 1;
const namaManifest = 'manifest.json';
const namaDbCadangan = 'sikaya.db';
const folderFotoAset = 'foto_aset';
const folderFotoInventaris = 'foto_inventaris';

/// Nama foto yang sah: aset tetap (lihat foto_aset.dart) dan inventaris per id barang.
final _namaFotoAset = RegExp(r'^aset_\d+_\d+\.jpg$');
final _namaFotoInventaris = RegExp(r'^inv_(\d+)\.(jpg|jpeg|png|webp|heic)$');
const _ekstensiFoto = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

/// File cadangan ditolak; data aplikasi tidak diubah.
class BackupInvalidException implements Exception {
  BackupInvalidException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

/// Isi sebuah database (file cadangan atau data saat ini), untuk konfirmasi.
class BackupSummary {
  const BackupSummary({
    required this.versi,
    required this.transaksi,
    required this.asetTetap,
    required this.inventaris,
    this.fotoAset = 0,
    this.fotoInventaris = 0,
    this.tanggalAwal,
    this.tanggalAkhir,
    this.ditutupSampai,
  });
  final int versi;
  final int transaksi;
  final int asetTetap;
  final int inventaris;

  /// Jumlah foto di zip cadangan (0 untuk file .db lama dan data saat ini).
  final int fotoAset;
  final int fotoInventaris;
  int get jumlahFoto => fotoAset + fotoInventaris;

  /// yyyy-MM-dd; null bila belum ada transaksi.
  final String? tanggalAwal;
  final String? tanggalAkhir;

  /// Tutup buku terakhir (yyyy-MM-dd); null bila belum pernah.
  final String? ditutupSampai;

  BackupSummary _denganFoto(int aset, int inv) => BackupSummary(
        versi: versi,
        transaksi: transaksi,
        asetTetap: asetTetap,
        inventaris: inventaris,
        fotoAset: aset,
        fotoInventaris: inv,
        tanggalAwal: tanggalAwal,
        tanggalAkhir: tanggalAkhir,
        ditutupSampai: ditutupSampai,
      );
}

/// Peringatan di dialog konfirmasi pulihkan: apa yang hilang bila [isi] menggantikan [sekarang].
String peringatanPulihkan(BackupSummary isi, BackupSummary sekarang) {
  final sampai = isi.tanggalAkhir == null
      ? 'Cadangan ini tidak berisi transaksi.'
      : 'Cadangan berisi transaksi sampai tanggal ${isi.tanggalAkhir}.';
  final semua = '$sampai Semua transaksi dan tutup buku yang dicatat sesudah cadangan ini '
      'dibuat akan HILANG.';
  final kunci = sekarang.ditutupSampai, kunciCadangan = isi.ditutupSampai;
  if (kunci == null || (kunciCadangan != null && kunci.compareTo(kunciCadangan) <= 0)) {
    return semua;
  }
  final cadangan = kunciCadangan == null
      ? 'cadangan belum pernah ditutup buku'
      : 'cadangan hanya ditutup sampai $kunciCadangan';
  return '$semua Tutup buku sampai $kunci pada data saat ini akan hilang; $cadangan.';
}

class RestoreResult {
  const RestoreResult(this.dipulihkan, this.cadanganOtomatis);

  /// Isi data yang sekarang aktif (= isi file cadangan).
  final BackupSummary dipulihkan;

  /// Salinan data sebelum dipulihkan (zip berisi DB dan foto).
  final String cadanganOtomatis;
}

/// Isi zip cadangan yang sudah diperiksa (utuh, manifest dikenal, nama aman).
class _IsiZip {
  _IsiZip(this.db, this.versiSkema, this.fotoAset, this.fotoInventaris);
  final Uint8List db;
  final int versiSkema;

  /// Nama file (tanpa folder) -> isi.
  final Map<String, Uint8List> fotoAset;
  final Map<String, Uint8List> fotoInventaris;
}

class BackupService {
  BackupService({
    required Future<Database> Function() open,
    required Future<void> Function() close,
    required DatabaseFactory Function() factory,
    Future<Directory?> Function()? folderFotoAset,
    Future<Directory?> Function()? folderFotoInventaris,
  })  : _open = open,
        _close = close,
        _factory = factory,
        _folderAset = folderFotoAset ?? _tanpaFolder,
        _folderInventaris = folderFotoInventaris ?? _tanpaFolder;

  final Future<Database> Function() _open;
  final Future<void> Function() _close;
  final DatabaseFactory Function() _factory;

  /// Folder foto aset tetap dan foto inventaris di HP; null = tanpa foto.
  final Future<Directory?> Function() _folderAset;
  final Future<Directory?> Function() _folderInventaris;

  static Future<Directory?> _tanpaFolder() async => null;

  /// Tanpa folder foto; aplikasi memakai layanan berfolder foto (lainnya_page.dart).
  static final BackupService instance = BackupService(
    open: () => DatabaseHelper.instance.database,
    close: DatabaseHelper.instance.close,
    factory: () => databaseFactory,
  );

  /// Isi data yang sedang dipakai.
  Future<BackupSummary> currentSummary() async => _summarize(await _open());

  /// Salin file DB yang sedang dipakai ke [destPath] (format lama, tanpa foto),
  /// lalu periksa salinannya (harus bisa dipulihkan). Mengembalikan [destPath].
  Future<String> exportTo(String destPath) async {
    final db = await _open();
    await _checkpoint(db);
    await File(db.path).copy(destPath);
    await inspect(destPath);
    return destPath;
  }

  /// Zip cadangan di [destPath]: salinan DB, foto aset tetap, foto inventaris
  /// (yang filenya ada), dan manifest.json. Zip yang dihasilkan diperiksa ulang.
  Future<String> exportZipTo(String destPath, {DateTime? waktu}) async {
    final db = await _open();
    await _checkpoint(db);
    final kerja = await Directory.systemTemp.createTemp('sikaya_ekspor');
    try {
      final salinan = p.join(kerja.path, namaDbCadangan);
      await File(db.path).copy(salinan);
      final ringkas = await _inspectDb(salinan);
      final arsip = Archive()..addFile(ArchiveFile.bytes(namaDbCadangan, await File(salinan).readAsBytes()));

      var nAset = 0;
      final dAset = await _folderAman(_folderAset);
      if (dAset != null && await dAset.exists()) {
        final daftar = await dAset.list().where((e) => e is File).cast<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in daftar) {
          final nama = p.basename(f.path);
          if (!_namaFotoAset.hasMatch(nama)) continue;
          // JPEG sudah terkompres saat diambil: disimpan tanpa kompresi ulang.
          final isi = await f.readAsBytes();
          arsip.addFile(ArchiveFile.noCompress('$folderFotoAset/$nama', isi.length, isi));
          nAset++;
        }
      }

      // Foto inventaris: path di kolom imagePath; di zip dinamai menurut id barang.
      var nInv = 0;
      final dbSalinan =
          await _factory().openDatabase(salinan, options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
      final List<Map<String, Object?>> barang;
      try {
        barang = await dbSalinan.query('assets', columns: ['id', 'imagePath'], orderBy: 'id');
      } finally {
        await dbSalinan.close();
      }
      for (final b in barang) {
        final path = b['imagePath'] as String? ?? '';
        if (path.isEmpty || !await File(path).exists()) continue;
        final eks = p.extension(path).toLowerCase();
        final isi = await File(path).readAsBytes();
        final nama = 'inv_${b['id']}${_ekstensiFoto.contains(eks) ? eks : '.jpg'}';
        arsip.addFile(ArchiveFile.noCompress('$folderFotoInventaris/$nama', isi.length, isi));
        nInv++;
      }

      arsip.addFile(ArchiveFile.string(
          namaManifest,
          const JsonEncoder.withIndent('  ').convert({
            'format': formatCadangan,
            'versiFormat': versiFormatCadangan,
            'versiSkema': ringkas.versi,
            'dibuat': (waktu ?? DateTime.now()).toIso8601String(),
            'jumlahFoto': {'aset': nAset, 'inventaris': nInv},
            'jumlahTransaksi': ringkas.transaksi,
          })));
      await File(destPath).writeAsBytes(ZipEncoder().encodeBytes(arsip), flush: true);
    } finally {
      await kerja.delete(recursive: true);
    }
    await inspect(destPath);
    return destPath;
  }

  /// Periksa file cadangan tanpa mengubah apa pun. Zip: utuh (CRC), manifest
  /// dikenal, nama file aman (tidak keluar folder), jumlah foto cocok, lalu DB di
  /// dalamnya seperti file .db. File .db: format SQLite, utuh, versi skema
  /// dikenal, tabel inti ada, dan semua baris terbaca oleh mesin akuntansi.
  Future<BackupSummary> inspect(String path) async {
    await _open(); // memastikan factory sudah diinisialisasi (desktop: ffi)
    final file = File(path);
    if (!await file.exists()) throw BackupInvalidException('File tidak ditemukan.');
    if (!await _zipHeader(file)) return _inspectDb(path);
    final zip = await _bacaZip(file);
    final kerja = await Directory.systemTemp.createTemp('sikaya_periksa');
    try {
      final db = p.join(kerja.path, namaDbCadangan);
      await File(db).writeAsBytes(zip.db, flush: true);
      return (await _inspectDbZip(db, zip))._denganFoto(zip.fotoAset.length, zip.fotoInventaris.length);
    } finally {
      await kerja.delete(recursive: true);
    }
  }

  /// Ganti data saat ini dengan isi [sourcePath] (zip atau .db lama). Urutan:
  /// periksa dan siapkan semua isi di samping file DB (gagal = data tidak
  /// disentuh), cadangkan kondisi saat ini sebagai zip (DB + foto), tutup
  /// koneksi, timpa file DB dan folder foto, buka lagi. File .db lama tidak
  /// membawa foto: foto di HP dibiarkan.
  Future<RestoreResult> restoreFrom(String sourcePath) async {
    final db = await _open();
    final target = db.path;
    final tmp = '$target.pulihkan';
    final tmpFoto = Directory('$target.pulihkan_foto');
    await _hapus(tmp);
    await _hapusFolder(tmpFoto);
    final dAset = await _folderAman(_folderAset), dInv = await _folderAman(_folderInventaris);
    final BackupSummary isi;
    var gantiFoto = false;
    try {
      final sumber = File(sourcePath);
      if (!await sumber.exists()) throw BackupInvalidException('File tidak ditemukan.');
      if (await _zipHeader(sumber)) {
        final zip = await _bacaZip(sumber);
        await File(tmp).writeAsBytes(zip.db, flush: true);
        isi = (await _inspectDbZip(tmp, zip))._denganFoto(zip.fotoAset.length, zip.fotoInventaris.length);
        for (final e in zip.fotoAset.entries) {
          await _tulisAman(Directory(p.join(tmpFoto.path, folderFotoAset)), e.key, e.value);
        }
        final pathBaru = <int, String>{};
        for (final e in zip.fotoInventaris.entries) {
          await _tulisAman(Directory(p.join(tmpFoto.path, folderFotoInventaris)), e.key, e.value);
          if (dInv != null) {
            pathBaru[int.parse(_namaFotoInventaris.firstMatch(e.key)!.group(1)!)] = p.join(dInv.path, e.key);
          }
        }
        await _gantiPathInventaris(tmp, pathBaru);
        gantiFoto = true;
      } else {
        await sumber.copy(tmp);
        isi = await _inspectDb(tmp);
      }
    } catch (e) {
      await _hapusDb(tmp);
      await _hapusFolder(tmpFoto);
      if (e is BackupInvalidException) rethrow;
      throw BackupInvalidException('File cadangan tidak bisa disalin: $e');
    }
    final otomatis =
        await exportZipTo('${p.withoutExtension(target)}_backup_sebelumpulih_${_stempel(DateTime.now())}.zip');
    await _close();
    for (final s in ['-wal', '-shm', '-journal']) {
      await _hapus('$target$s');
    }
    await File(tmp).rename(target);
    if (gantiFoto) {
      for (final (folder, nama) in [(dAset, folderFotoAset), (dInv, folderFotoInventaris)]) {
        if (folder == null) continue;
        await _hapusFolder(folder);
        final siap = Directory(p.join(tmpFoto.path, nama));
        if (await siap.exists()) await _pindahFolder(siap, folder);
      }
    }
    await _hapusFolder(tmpFoto);
    await _open();
    return RestoreResult(isi, otomatis);
  }

  Future<BackupSummary> _inspectDbZip(String db, _IsiZip zip) async {
    final isi = await _inspectDb(db);
    if (isi.versi != zip.versiSkema) {
      throw BackupInvalidException('File cadangan rusak: versi skema di manifest (${zip.versiSkema}) '
          'tidak sama dengan database (${isi.versi}).');
    }
    return isi;
  }

  Future<BackupSummary> _inspectDb(String path) async {
    if (!await _sqliteHeader(File(path))) {
      throw BackupInvalidException('Bukan file cadangan SiKaya (bukan zip cadangan, bukan database SQLite).');
    }
    Database? db;
    try {
      db = await _factory().openDatabase(path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
      final cek = (await db.rawQuery('PRAGMA quick_check')).first.values.first;
      if (cek != 'ok') throw BackupInvalidException('File cadangan rusak ($cek).');
      final versi = await db.getVersion();
      if (versi > dbVersion) {
        throw BackupInvalidException('Cadangan dibuat aplikasi yang lebih baru (skema $versi; '
            'aplikasi ini skema $dbVersion). Perbarui aplikasi dulu.');
      }
      if (versi < minRestorableVersion) {
        throw BackupInvalidException(versi == 0
            ? 'Bukan file cadangan SiKaya (versi skema tidak ada).'
            : 'Cadangan skema $versi berasal dari versi lama sebelum pembukuan SAK EMKM '
                'dan tidak bisa dipulihkan.');
      }
      final tabel = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((r) => r['name'])
          .toSet();
      final kurang = coreTables.difference(tabel);
      if (kurang.isNotEmpty) {
        throw BackupInvalidException('File cadangan tidak lengkap: tabel ${kurang.join(', ')} tidak ada.');
      }
      // Baris harus terbaca model dan mesin (tx_type/enum dikenal, aset tetap valid).
      final rows = (await db.query('transactions')).map(TransactionModel.fromMap).toList();
      final aset = (await db.query('fixed_assets')).map(FixedAssetModel.fromMap).toList();
      final input = AccountingRepository.buildEngineInput(rows, aset);
      buildReport(input.txs, input.assets, asOf: DateTime(9999, 12, 31));
      return await _summarize(db);
    } on BackupInvalidException {
      rethrow;
    } catch (e) {
      throw BackupInvalidException('File cadangan rusak atau bukan dari SiKaya ($e).');
    } finally {
      await db?.close();
    }
  }

  /// Baca dan periksa zip cadangan di memori. Tidak menulis apa pun.
  static Future<_IsiZip> _bacaZip(File file) async {
    final bytes = await file.readAsBytes();
    final dekoder = ZipDecoder();
    try {
      dekoder.decodeBytes(bytes);
    } catch (e) {
      throw BackupInvalidException('File cadangan rusak: zip tidak utuh.');
    }
    // Zip terpotong: direktori di ujung file hilang, tidak ada entri yang terbaca.
    if (dekoder.directory.fileHeaders.isEmpty) {
      throw BackupInvalidException('File cadangan rusak: zip tidak utuh atau kosong.');
    }
    Uint8List? db;
    Map<String, Object?>? manifest;
    final fotoAset = <String, Uint8List>{}, fotoInventaris = <String, Uint8List>{};
    final dilihat = <String>{};
    for (final h in dekoder.directory.fileHeaders) {
      final nama = h.filename;
      if (!_jalurAman(nama)) {
        throw BackupInvalidException('File cadangan ditolak: jalur file berbahaya ($nama).');
      }
      if (!dilihat.add(nama)) throw BackupInvalidException('File cadangan rusak: nama file ganda ($nama).');
      if (nama.endsWith('/')) {
        if (nama == '$folderFotoAset/' || nama == '$folderFotoInventaris/') continue;
        throw BackupInvalidException('File cadangan ditolak: folder tidak dikenal ($nama).');
      }
      final Uint8List isi;
      try {
        final zf = h.file!;
        if (!zf.verifyCrc32()) throw const FormatException('CRC tidak cocok');
        isi = zf.getStream().toUint8List();
      } catch (_) {
        throw BackupInvalidException('File cadangan rusak: isi zip tidak utuh ($nama).');
      }
      final bagian = nama.split('/');
      if (nama == namaDbCadangan) {
        db = isi;
      } else if (nama == namaManifest) {
        try {
          manifest = (jsonDecode(utf8.decode(isi)) as Map).cast<String, Object?>();
        } catch (_) {
          throw BackupInvalidException('Manifest cadangan tidak dikenal (bukan JSON).');
        }
      } else if (bagian.length == 2 && bagian[0] == folderFotoAset && _namaFotoAset.hasMatch(bagian[1])) {
        fotoAset[bagian[1]] = isi;
      } else if (bagian.length == 2 && bagian[0] == folderFotoInventaris && _namaFotoInventaris.hasMatch(bagian[1])) {
        fotoInventaris[bagian[1]] = isi;
      } else {
        throw BackupInvalidException('File cadangan ditolak: berisi file tidak dikenal ($nama).');
      }
    }
    if (manifest == null) {
      throw BackupInvalidException('Manifest cadangan tidak ada; bukan zip cadangan SiKaya.');
    }
    if (manifest['format'] != formatCadangan || manifest['versiFormat'] != versiFormatCadangan) {
      throw BackupInvalidException('Manifest cadangan tidak dikenal (format ${manifest['format']}, '
          'versi ${manifest['versiFormat']}). Bila cadangan dibuat aplikasi yang lebih baru, perbarui aplikasi dulu.');
    }
    final versi = manifest['versiSkema'], jumlah = manifest['jumlahFoto'];
    if (versi is! int || jumlah is! Map) {
      throw BackupInvalidException('Manifest cadangan tidak dikenal (isian kurang).');
    }
    if (jumlah['aset'] != fotoAset.length || jumlah['inventaris'] != fotoInventaris.length) {
      throw BackupInvalidException('File cadangan rusak: jumlah foto tidak sama dengan manifest.');
    }
    if (db == null) throw BackupInvalidException('File cadangan rusak: database tidak ada di dalam zip.');
    return _IsiZip(db, versi, fotoAset, fotoInventaris);
  }

  /// Nama entri zip relatif tanpa "..", "\", awalan "/", atau huruf drive.
  static bool _jalurAman(String nama) {
    if (nama.isEmpty || nama.startsWith('/') || nama.contains(r'\') || nama.contains(':')) return false;
    final isi = nama.endsWith('/') ? nama.substring(0, nama.length - 1) : nama;
    return isi.split('/').every((b) => b.isNotEmpty && b != '.' && b != '..');
  }

  /// Tulis [isi] sebagai [nama] di [folder]; tujuan wajib tetap di dalam [folder].
  static Future<void> _tulisAman(Directory folder, String nama, Uint8List isi) async {
    final tujuan = p.normalize(p.join(folder.path, nama));
    if (!p.isWithin(folder.path, tujuan)) {
      throw BackupInvalidException('File cadangan ditolak: jalur file berbahaya ($nama).');
    }
    await File(tujuan).create(recursive: true);
    await File(tujuan).writeAsBytes(isi, flush: true);
  }

  /// Kolom imagePath barang inventaris di DB salinan menunjuk foto hasil pulihan.
  Future<void> _gantiPathInventaris(String path, Map<int, String> pathBaru) async {
    if (pathBaru.isEmpty) return;
    final db = await _factory().openDatabase(path, options: OpenDatabaseOptions(singleInstance: false));
    try {
      await db.transaction((t) async {
        for (final e in pathBaru.entries) {
          await t.update('assets', {'imagePath': e.value}, where: 'id = ?', whereArgs: [e.key]);
        }
      });
      await _checkpoint(db);
    } finally {
      await db.close();
    }
    for (final s in ['-wal', '-shm', '-journal']) {
      await _hapus('$path$s');
    }
  }

  static Future<Directory?> _folderAman(Future<Directory?> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null; // folder tidak tersedia: tanpa foto
    }
  }

  static Future<void> _pindahFolder(Directory dari, Directory ke) async {
    await ke.parent.create(recursive: true);
    try {
      await dari.rename(ke.path);
    } on FileSystemException {
      // Beda sistem file: salin lalu hapus.
      await ke.create(recursive: true);
      await for (final e in dari.list()) {
        if (e is File) await e.copy(p.join(ke.path, p.basename(e.path)));
      }
      await dari.delete(recursive: true);
    }
  }

  static Future<BackupSummary> _summarize(Database db) async {
    Future<int> jumlah(String t) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $t')).first['n'] as int;
    final rentang =
        (await db.rawQuery('SELECT MIN(date) AS a, MAX(date) AS b FROM transactions')).first;
    final tutup = (await db.rawQuery('SELECT MAX(closed_until) AS t FROM period_closings')).first;
    return BackupSummary(
      versi: await db.getVersion(),
      transaksi: await jumlah('transactions'),
      asetTetap: await jumlah('fixed_assets'),
      inventaris: await jumlah('assets'),
      tanggalAwal: rentang['a'] as String?,
      tanggalAkhir: rentang['b'] as String?,
      ditutupSampai: tutup['t'] as String?,
    );
  }

  /// Pindahkan isi WAL (bila ada) ke file utama agar satu file = seluruh data.
  static Future<void> _checkpoint(Database db) =>
      db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

  static Future<bool> _sqliteHeader(File f) async =>
      String.fromCharCodes(await _kepala(f, 16)) == 'SQLite format 3\x00';

  /// Tanda awal file zip: "PK\x03\x04".
  static Future<bool> _zipHeader(File f) async {
    final h = await _kepala(f, 4);
    return h.length == 4 && h[0] == 0x50 && h[1] == 0x4B && h[2] == 0x03 && h[3] == 0x04;
  }

  static Future<List<int>> _kepala(File f, int n) async {
    final raf = await f.open();
    try {
      return await raf.read(n);
    } finally {
      await raf.close();
    }
  }

  static Future<void> _hapus(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> _hapusDb(String path) async {
    for (final s in ['', '-wal', '-shm', '-journal']) {
      await _hapus('$path$s');
    }
  }

  static Future<void> _hapusFolder(Directory d) async {
    if (await d.exists()) await d.delete(recursive: true);
  }
}
