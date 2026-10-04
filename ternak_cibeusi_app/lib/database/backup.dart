// Cadangan yang bisa diakses pengguna: ekspor salinan file DB, periksa file
// cadangan, dan pulihkan. Tanpa Flutter/UI: share sheet dan pemilih file ada di
// settings_page.dart, sehingga alur ini bisa dites dengan sqflite_ffi.
import 'dart:io';

import 'package:intl/intl.dart';
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

/// `SiKaya_cadangan_v<skema>_<yyyyMMdd_HHmmss>.db`
String backupFileName(DateTime now) =>
    'SiKaya_cadangan_v${dbVersion}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.db';

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
    this.tanggalAwal,
    this.tanggalAkhir,
    this.ditutupSampai,
  });
  final int versi;
  final int transaksi;
  final int asetTetap;
  final int inventaris;

  /// yyyy-MM-dd; null bila belum ada transaksi.
  final String? tanggalAwal;
  final String? tanggalAkhir;

  /// Tutup buku terakhir (yyyy-MM-dd); null bila belum pernah.
  final String? ditutupSampai;
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

  /// Salinan data sebelum dipulihkan.
  final String cadanganOtomatis;
}

class BackupService {
  BackupService({
    required Future<Database> Function() open,
    required Future<void> Function() close,
    required DatabaseFactory Function() factory,
  })  : _open = open,
        _close = close,
        _factory = factory;

  final Future<Database> Function() _open;
  final Future<void> Function() _close;
  final DatabaseFactory Function() _factory;

  static final BackupService instance = BackupService(
    open: () => DatabaseHelper.instance.database,
    close: DatabaseHelper.instance.close,
    factory: () => databaseFactory,
  );

  /// Isi data yang sedang dipakai.
  Future<BackupSummary> currentSummary() async => _summarize(await _open());

  /// Salin file DB yang sedang dipakai ke [destPath], lalu periksa salinannya
  /// (harus bisa dipulihkan). Mengembalikan [destPath].
  Future<String> exportTo(String destPath) async {
    final db = await _open();
    await _checkpoint(db);
    await File(db.path).copy(destPath);
    await inspect(destPath);
    return destPath;
  }

  /// Periksa file cadangan tanpa mengubah apa pun: format SQLite, utuh, versi
  /// skema dikenal, tabel inti ada, dan semua baris terbaca oleh mesin akuntansi.
  Future<BackupSummary> inspect(String path) async {
    await _open(); // memastikan factory sudah diinisialisasi (desktop: ffi)
    final file = File(path);
    if (!await file.exists()) throw BackupInvalidException('File tidak ditemukan.');
    if (!await _sqliteHeader(file)) {
      throw BackupInvalidException('Bukan file cadangan SiKaya (bukan database SQLite).');
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

  /// Ganti data saat ini dengan isi [sourcePath]. Urutan: salin file ke folder DB
  /// lalu periksa salinan itu (gagal = data tidak disentuh), cadangkan data saat
  /// ini, tutup koneksi, timpa file DB, buka lagi.
  Future<RestoreResult> restoreFrom(String sourcePath) async {
    final db = await _open();
    final target = db.path;
    final tmp = '$target.pulihkan';
    await _hapus(tmp);
    final BackupSummary isi;
    try {
      await File(sourcePath).copy(tmp);
      isi = await inspect(tmp);
    } catch (e) {
      await _hapus(tmp);
      if (e is BackupInvalidException) rethrow;
      throw BackupInvalidException('File cadangan tidak bisa disalin: $e');
    }
    await _checkpoint(db);
    final otomatis = await DatabaseHelper.copyDatabaseFile(target, 'sebelumpulih');
    await _close();
    for (final s in ['-wal', '-shm', '-journal']) {
      await _hapus('$target$s');
    }
    await File(tmp).rename(target);
    await _open();
    return RestoreResult(isi, otomatis);
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

  static Future<bool> _sqliteHeader(File f) async {
    final raf = await f.open();
    try {
      final head = await raf.read(16);
      return String.fromCharCodes(head) == 'SQLite format 3\x00';
    } finally {
      await raf.close();
    }
  }

  static Future<void> _hapus(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
