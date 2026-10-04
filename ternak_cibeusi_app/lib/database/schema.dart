// Skema SQLite SiKaya. Versi 2 = akuntansi SAK EMKM (PLAN-FASE1.md tahap 2).
// Uang = INTEGER Rupiah. Tipe transaksi eksplisit (tx_type), bukan nama kategori.
import 'package:sqflite/sqflite.dart';

import '../accounting/models.dart';

const int dbVersion = 2;

String _inList(Iterable<String> v) => v.map((s) => "'$s'").join(', ');

Future<void> configureDb(Database db) => db.execute('PRAGMA foreign_keys = ON');

/// Membuat seluruh tabel versi terbaru (instalasi baru).
Future<void> createSchema(Database db, int version) => _createV2(db);

/// Migrasi bertahap. Tambahkan blok `if (oldVersion < N)` untuk versi berikutnya.
Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // v1 belum berisi data riil (PLAN-FASE1 bagian 1): file lama sudah dibackup
    // oleh DatabaseHelper sebelum dibuka; tabel dibuat ulang tanpa pemetaan kategori lama.
    for (final t in ['period_closings', 'transactions', 'fixed_assets', 'assets']) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
    await _createV2(db);
  }
}

Future<void> _createV2(DatabaseExecutor db) async {
  // Inventaris non-keuangan (halaman Aset lama), struktur sama dengan v1.
  await db.execute('''
    CREATE TABLE assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      imagePath TEXT NOT NULL,
      date TEXT NOT NULL,
      condition TEXT NOT NULL,
      unit TEXT,
      expired_date TEXT,
      usage_ternak INTEGER,
      usage_days INTEGER,
      ownership_status TEXT,
      land_function TEXT
    )
  ''');

  // Aset tetap: TANPA kolom harga. Harga perolehan = amount transaksi
  // beli_aset_tetap yang asset_id-nya menunjuk baris ini.
  await db.execute('''
    CREATE TABLE fixed_assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      ready_date TEXT CHECK (ready_date IS NULL OR ready_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
      life_months INTEGER CHECK (life_months IS NULL OR life_months > 0),
      description TEXT NOT NULL DEFAULT ''
    )
  ''');

  await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tx_type TEXT NOT NULL CHECK (tx_type IN (${_inList(TxType.values.map((t) => t.code))})),
      amount INTEGER NOT NULL CHECK (typeof(amount) = 'integer' AND (amount >= 0 OR tx_type = 'tutup_buku')),
      date TEXT NOT NULL CHECK (date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
      qty INTEGER CHECK (qty IS NULL OR qty > 0),
      item TEXT CHECK (item IS NULL OR item IN (${_inList(StockItem.values.map((e) => e.name))})),
      expense_kind TEXT CHECK (expense_kind IS NULL OR expense_kind IN (${_inList(ExpenseKind.values.map((e) => e.name))})),
      payment_source TEXT NOT NULL DEFAULT 'kas' CHECK (payment_source IN ('kas', 'utang')),
      ref_id INTEGER REFERENCES transactions(id),
      reversal_of INTEGER REFERENCES transactions(id),
      asset_id INTEGER REFERENCES fixed_assets(id),
      category TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      perlu_ditinjau INTEGER NOT NULL DEFAULT 0 CHECK (perlu_ditinjau IN (0, 1)),
      review_note TEXT
    )
  ''');
  await db.execute('CREATE INDEX ix_transactions_date ON transactions(date, id)');
  // Satu aset tetap = satu transaksi beli (sumber harga perolehan).
  await db.execute('''
    CREATE UNIQUE INDEX ux_transactions_asset_purchase ON transactions(asset_id)
    WHERE tx_type = 'beli_aset_tetap' AND reversal_of IS NULL
  ''');

  // Arsip tutup buku (diisi pada tahap 4; belum dipakai).
  await db.execute('''
    CREATE TABLE period_closings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      closed_until TEXT NOT NULL UNIQUE CHECK (closed_until GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
      closing_tx_id INTEGER REFERENCES transactions(id),
      laba_bersih INTEGER NOT NULL,
      total_aset INTEGER NOT NULL,
      saldo_laba INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}
