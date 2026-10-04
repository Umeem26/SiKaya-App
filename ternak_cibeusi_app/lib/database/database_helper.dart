import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../asset_model.dart';
import 'schema.dart';

/// Koneksi SQLite + CRUD inventaris aset. Transaksi keuangan dan laporan
/// lewat AccountingRepository (lib/accounting/repository.dart).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sikaya_platinum_combo_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    return openAppDatabase(join(dbPath, filePath), databaseFactory);
  }

  /// Buka DB pada versi [dbVersion]. Bila file versi lama ada, file itu disalin
  /// dulu (backup) sebelum migrasi membuat ulang tabel.
  static Future<Database> openAppDatabase(String path, DatabaseFactory factory) async {
    await backupIfOutdated(path, factory);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onConfigure: configureDb,
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
      ),
    );
  }

  /// Salin file DB (beserta -wal/-shm/-journal bila ada) bila versinya < [dbVersion].
  /// Mengembalikan path backup, atau null bila tidak perlu.
  static Future<String?> backupIfOutdated(String path, DatabaseFactory factory) async {
    if (!await File(path).exists()) return null;
    final old = await factory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true));
    final version = await old.getVersion();
    await old.close();
    if (version >= dbVersion) return null;
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backup = '${withoutExtension(path)}_backup_v${version}_$stamp${extension(path)}';
    await File(path).copy(backup);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$path$suffix');
      if (await f.exists()) await f.copy('$backup$suffix');
    }
    return backup;
  }

  // --- CRUD ASSET (inventaris, tidak dihitung di laporan keuangan) ---
  Future<int> create(AssetModel asset) async {
    final db = await instance.database;
    return await db.insert('assets', asset.toMap());
  }
  Future<List<AssetModel>> readAllAssets() async {
    final db = await instance.database;
    final result = await db.query('assets', orderBy: 'date DESC');
    return result.map((json) => AssetModel.fromMap(json)).toList();
  }
  Future<int> update(AssetModel asset) async {
    final db = await instance.database;
    return db.update('assets', asset.toMap(), where: 'id = ?', whereArgs: [asset.id]);
  }
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }
  Future<void> nukeDatabase() async {
    final db = await instance.database;
    await db.delete('period_closings');
    await db.delete('transactions');
    await db.delete('fixed_assets');
    await db.delete('assets');
  }
  // Tahap 4: ganti dengan tutup buku non-destruktif (period_closings).
  Future<void> closeBookAndReset() async {
    final db = await instance.database;
    await db.delete('transactions');
  }
}
