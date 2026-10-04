// Repository end-to-end: SQLite in-memory (sqflite_common_ffi) -> TransactionModel -> mesin -> laporan.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/database/schema.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'helpers.dart';

Future<Database> openMemoryDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onConfigure: configureDb,
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );

Future<int> count(Database db, String table) async =>
    (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n'] as int;

TransactionModel row(
  String date,
  TxType type, {
  int amount = 0,
  int? qty,
  StockItem? item,
  ExpenseKind? expense,
  PaymentSource source = PaymentSource.kas,
  int? refId,
  int? reversalOf,
  int? assetId,
  String category = '',
}) =>
    TransactionModel(
      txType: type,
      amount: amount,
      date: date,
      qty: qty,
      item: item,
      expenseKind: expense,
      paymentSource: source,
      refId: refId,
      reversalOf: reversalOf,
      assetId: assetId,
      category: category,
    );

/// Skenario campuran E7 (helpers.skenarioCampuran) lewat DB. Urutan insert = id 1..9.
Future<void> seedCampuran(AccountingRepository repo) async {
  final asetId = await repo.insertFixedAsset(const FixedAssetModel(
      name: 'Peralatan kandang', readyDate: '2026-01-10', lifeMonths: 12));
  for (final t in [
    row('2026-01-02', TxType.setorModal, amount: 5000000),
    row('2026-01-03', TxType.terimaPinjaman, amount: 2000000),
    row('2026-01-04', TxType.bayarCicilanPokok, amount: 500000),
    row('2026-01-05', TxType.prive, amount: 300000),
    row('2026-01-06', TxType.beliPersediaanTunai,
        amount: 1000000, qty: 100, item: StockItem.pakan, category: 'Beli Pakan'),
    row('2026-01-07', TxType.pakaiPersediaan, qty: 40, item: StockItem.pakan),
    row('2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: asetId),
    row('2026-01-12', TxType.penjualanKredit, amount: 3000000),
    row('2026-01-20', TxType.terimaPiutang, amount: 3000000, refId: 8),
  ]) {
    await repo.insertTransaction(t);
  }
}

void main() {
  sqfliteFfiInit();
  final jan31 = d('2026-01-31');
  late Database db;
  late AccountingRepository repo;

  setUp(() async {
    db = await openMemoryDb();
    repo = AccountingRepository(() async => db);
  });
  tearDown(() => db.close());

  group('E1-E7 end-to-end dari DB sampai laporan', () {
    test('E7 per 2026-01-31: angka manual', () async {
      await seedCampuran(repo);
      final lp = await repo.loadReport(asOf: jan31);
      final r = lp.report;
      expect(r.kas, 7000000); // 5.000.000 + 2.000.000 - 500.000 - 300.000 - 1.000.000 - 1.200.000 + 3.000.000
      expect(r.piutang, 0); // 3.000.000 - 3.000.000
      expect(r.persediaan[StockItem.pakan], 600000); // E1: 1.000.000 - 1.000.000 x 40/100
      expect(r.beban[ExpenseKind.pakan], 400000); // E1: 1.000.000 x 40/100
      expect(r.modalDisetor, 5000000); // E2: setor 5.000.000
      expect(r.utang, 1500000); // E3: 2.000.000 - 500.000
      expect(r.prive, 300000); // E4: prive 300.000
      expect(r.asetTetapBruto, 1200000); // E5: harga dari transaksi beli_aset_tetap 1.200.000
      expect(r.akumulasiPenyusutan, 100000); // E5: 1.200.000/12 x 1 bulan
      expect(r.pendapatan, 3000000); // E6: penjualan kredit 3.000.000 (pelunasan bukan pendapatan)
      expect(r.bebanTotal, 500000); // 400.000 + 100.000
      expect(r.labaBersih, 2500000); // 3.000.000 - 500.000
      expect(r.saldoLaba, 2200000); // 2.500.000 - 300.000
      expect(r.totalAset, 8700000); // 7.000.000 + 600.000 + 1.200.000 - 100.000
      expect(r.totalLiabilitasEkuitas, 8700000); // 1.500.000 + 5.000.000 + 2.200.000
      expect(r.balanced, isTrue);
      expect(r.perluDitinjau, isEmpty);
      expect(lp.kas.masuk, 10000000); // 5.000.000 + 2.000.000 + 3.000.000
      expect(lp.kas.keluar, 3000000); // 500.000 + 300.000 + 1.000.000 + 1.200.000
      expect(lp.kas.saldo, r.kas); // D3: buku kas = kas laporan
    });

    test('hasil lewat DB identik dengan mesin langsung (konversi baris tanpa kehilangan)', () async {
      await seedCampuran(repo);
      final viaDb = (await repo.loadReport(asOf: jan31)).report;
      final langsung = buildReport(skenarioCampuran(), [peralatan], asOf: jan31);
      expect(viaDb.kas, langsung.kas); // 7.000.000
      expect(viaDb.totalAset, langsung.totalAset); // 8.700.000
      expect(viaDb.labaBersih, langsung.labaBersih); // 2.500.000
      expect(viaDb.saldoLaba, langsung.saldoLaba); // 2.200.000
      expect(viaDb.beban, langsung.beban); // {pakan 400.000, penyusutan 100.000}
    });

    test('D2 periode Februari lewat DB: laba = perubahan saldo laba', () async {
      await seedCampuran(repo);
      await repo.insertTransaction(row('2026-02-10', TxType.penjualanTunai, amount: 500000));
      await repo.insertTransaction(row('2026-02-15', TxType.prive, amount: 100000));
      final feb = (await repo.loadReport(asOf: d('2026-02-28'), from: d('2026-02-01'))).report;
      expect(feb.pendapatan, 500000); // penjualan tunai Feb
      expect(feb.beban[ExpenseKind.penyusutan], 100000); // akumulasi Feb 200.000 - Jan 100.000
      expect(feb.labaBersih, 400000); // 500.000 - 100.000
      expect(feb.saldoLaba, 2500000); // 2.200.000 + 400.000 - prive Feb 100.000
      expect(feb.balanced, isTrue);
    });

    test('per 2026-01-19 (sebelum pelunasan): kas 4.000.000, piutang 3.000.000', () async {
      await seedCampuran(repo);
      final lp = await repo.loadReport(asOf: d('2026-01-19'));
      expect(lp.report.kas, 4000000); // 7.000.000 - pelunasan 3.000.000
      expect(lp.report.piutang, 3000000); // penjualan kredit belum dilunasi
      expect(lp.kas.saldo, 4000000); // buku kas sama
      expect(lp.report.balanced, isTrue);
    });
  });

  group('aset tetap: harga perolehan dari transaksi beli', () {
    test('tanpa kolom harga: penyusutan mengikuti amount transaksi yang ditautkan', () async {
      final id = await repo.insertFixedAsset(
          const FixedAssetModel(name: 'Kandang', readyDate: '2026-01-10', lifeMonths: 12));
      await repo.insertTransaction(
          row('2026-01-10', TxType.beliAsetTetap, amount: 1000000, assetId: id));
      final r = (await repo.loadReport(asOf: d('2026-11-30'))).report;
      expect(r.asetTetapBruto, 1000000); // amount transaksi beli
      expect(r.akumulasiPenyusutan, 916663); // 1.000.000/12 = 83.333 x 11 bulan (Jan-Nov)
    });

    test('tanggal siap pakai kosong = tanggal transaksi beli', () async {
      final id = await repo.insertFixedAsset(const FixedAssetModel(name: 'Motor', lifeMonths: 12));
      await repo.insertTransaction(
          row('2026-03-15', TxType.beliAsetTetap, amount: 1200000, assetId: id));
      expect((await repo.loadReport(asOf: d('2026-02-28'))).report.akumulasiPenyusutan, 0); // belum dibeli
      expect((await repo.loadReport(asOf: d('2026-03-31'))).report.akumulasiPenyusutan, 100000); // 1.200.000/12 x 1 (Mar)
    });

    test('aset tanpa transaksi beli tidak muncul di laporan', () async {
      await repo.insertFixedAsset(const FixedAssetModel(name: 'Belum dibeli', lifeMonths: 12));
      final r = (await repo.loadReport(asOf: jan31)).report;
      expect(r.asetTetapBruto, 0); // tidak ada transaksi beli
      expect(r.akumulasiPenyusutan, 0); // tidak ada yang disusutkan
    });
  });

  group('perlu_ditinjau: disimpan, ditandai di DB, tidak dihitung', () {
    test('pemakaian melebihi stok tersimpan dengan flag; flag hilang bila stok dicukupi', () async {
      await repo.insertTransaction(row('2026-01-02', TxType.beliPersediaanTunai,
          amount: 1000000, qty: 100, item: StockItem.pakan));
      final pakaiId = await repo.insertTransaction(
          row('2026-01-10', TxType.pakaiPersediaan, qty: 120, item: StockItem.pakan));

      final tersimpan = (await repo.transactions()).firstWhere((t) => t.id == pakaiId);
      expect(tersimpan.perluDitinjau, isTrue);
      expect(tersimpan.reviewNote, contains('diminta 120, tersedia 100'));

      final r = (await repo.loadReport(asOf: jan31)).report;
      expect(r.beban[ExpenseKind.pakan] ?? 0, 0); // pemakaian dikeluarkan
      expect(r.persediaan[StockItem.pakan], 1000000); // 1.000.000 - 0
      expect(r.peringatanTinjau!.jumlahTransaksi, 1); // id pemakaian
      expect(r.peringatanTinjau!.totalNilai, 1200000); // taksiran 1.000.000 x 120/100

      // tambah 50 kg @10.000 sebelum pemakaian -> stok 150 >= 120
      await repo.insertTransaction(row('2026-01-05', TxType.beliPersediaanTunai,
          amount: 500000, qty: 50, item: StockItem.pakan));
      final lagi = (await repo.transactions()).firstWhere((t) => t.id == pakaiId);
      expect(lagi.perluDitinjau, isFalse);
      expect(lagi.reviewNote, isNull);
      final r2 = (await repo.loadReport(asOf: jan31)).report;
      expect(r2.beban[ExpenseKind.pakan], 1200000); // 1.500.000 x 120/150
      expect(r2.persediaan[StockItem.pakan], 300000); // 1.500.000 - 1.200.000
      expect(r2.peringatanTinjau, isNull);
    });
  });

  group('skema v2', () {
    test('baris bolak-balik DB tanpa kehilangan field', () async {
      final asetId = await repo.insertFixedAsset(const FixedAssetModel(name: 'x', lifeMonths: 3));
      final id1 = await repo.insertTransaction(row('2026-01-02', TxType.penjualanKredit, amount: 7));
      final id2 = await repo.insertTransaction(row('2026-01-03', TxType.bebanOperasional,
          amount: 11, expense: ExpenseKind.listrikAir, source: PaymentSource.utang,
          category: 'Listrik'));
      await repo.insertTransaction(row('2026-01-04', TxType.terimaPiutang, amount: 5, refId: id1));
      await repo.insertTransaction(row('2026-01-05', TxType.bebanOperasional,
          amount: 11, expense: ExpenseKind.listrikAir, source: PaymentSource.utang, reversalOf: id2));
      await repo.insertTransaction(row('2026-01-06', TxType.beliAsetTetap, amount: 9, assetId: asetId));
      final rows = (await repo.transactions()).reversed.toList();
      expect(rows.map((t) => t.txType), [
        TxType.penjualanKredit, TxType.bebanOperasional, TxType.terimaPiutang,
        TxType.bebanOperasional, TxType.beliAsetTetap,
      ]);
      expect(rows[1].paymentSource, PaymentSource.utang);
      expect(rows[1].expenseKind, ExpenseKind.listrikAir);
      expect(rows[1].category, 'Listrik');
      expect(rows[2].refId, id1);
      expect(rows[3].reversalOf, id2);
      expect(rows[4].assetId, asetId);
      expect(rows[1].arahKas, 0); // beban dibayar utang: tidak menyentuh kas
      expect(rows[2].arahKas, 1); // terima piutang: kas masuk
    });

    test('semua 16 tx_type diterima skema', () async {
      for (final t in TxType.values) {
        await db.insert('transactions', {'tx_type': t.code, 'amount': 0, 'date': '2026-01-01'});
      }
      expect(await count(db, 'transactions'),
          16); // 15 tipe spec C + kematian_ternak
    });

    test('ditolak skema: uang pecahan, tipe tak dikenal, tanggal salah, beli aset ganda, rujukan hilang', () async {
      Future<void> gagal(Map<String, Object?> v) => expectLater(
          db.insert('transactions', {'date': '2026-01-01', 'amount': 1, 'tx_type': 'prive', ...v}),
          throwsA(isA<DatabaseException>()));
      await gagal({'amount': 1000.5});
      await gagal({'tx_type': 'Jual Hasil Ternak Tunai'});
      await gagal({'date': '01/01/2026'});
      await gagal({'amount': -1});
      await gagal({'payment_source': 'bank'});
      await gagal({'reversal_of': 999});
      final asetId = await repo.insertFixedAsset(const FixedAssetModel(name: 'x', lifeMonths: 3));
      await repo.insertTransaction(row('2026-01-01', TxType.beliAsetTetap, amount: 5, assetId: asetId));
      await gagal({'tx_type': 'beli_aset_tetap', 'asset_id': asetId});
    });

    test('hapus transaksi yang dirujuk retur ditolak (FK)', () async {
      final id = await repo.insertTransaction(row('2026-01-02', TxType.penjualanTunai, amount: 10));
      await repo.insertTransaction(
          row('2026-01-03', TxType.penjualanTunai, amount: 10, reversalOf: id));
      await expectLater(repo.deleteTransaction(id), throwsA(isA<DatabaseException>()));
      expect((await repo.transactions()).length, 2); // asli + retur tetap ada
    });
  });

  group('migrasi v1 -> v2', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('sikaya_mig'));
    tearDown(() async => dir.delete(recursive: true));

    test('file v1 dibackup otomatis, tabel dibuat ulang tanpa pemetaan kategori', () async {
      final path = p.join(dir.path, 'sikaya.db');
      final v1 = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, '
                  'type TEXT, amount REAL, category TEXT, description TEXT, date TEXT, qty INTEGER, price REAL)');
              await db.execute('CREATE TABLE assets(id INTEGER PRIMARY KEY, name TEXT)');
            },
          ));
      await v1.insert('transactions',
          {'type': 'IN', 'amount': 1500.5, 'category': 'Jual Hasil Ternak Tunai', 'date': '2025-12-01'});
      await v1.close();

      final v2 = await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi);
      expect(await v2.getVersion(), 2); // dbVersion
      expect(await count(v2, 'transactions'),
          0); // data lama tidak dipetakan
      final kolom = (await v2.rawQuery('PRAGMA table_info(transactions)')).map((c) => c['name']);
      expect(kolom, containsAll(['tx_type', 'payment_source', 'reversal_of', 'perlu_ditinjau', 'asset_id']));
      final fa = (await v2.rawQuery('PRAGMA table_info(fixed_assets)')).map((c) => c['name']);
      expect(fa, containsAll(['ready_date', 'life_months']));
      expect(fa.any((n) => '$n'.contains('cost') || '$n'.contains('price')), isFalse);
      expect(await v2.rawQuery("SELECT 1 FROM sqlite_master WHERE name = 'period_closings'"), hasLength(1));
      await v2.close();

      final backups = dir.listSync().whereType<File>()
          .where((f) => p.basename(f.path).startsWith('sikaya_backup_v1_')).toList();
      expect(backups, hasLength(1)); // satu file backup
      final lama = await databaseFactoryFfi.openDatabase(backups.single.path,
          options: OpenDatabaseOptions(readOnly: true));
      expect(await lama.getVersion(), 1); // backup tetap versi 1
      final isi = await lama.query('transactions');
      expect(isi.single['amount'], 1500.5); // data lama utuh di backup
      expect(isi.single['category'], 'Jual Hasil Ternak Tunai');
      await lama.close();

      // buka lagi (sudah v2): tidak membuat backup baru
      await (await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi)).close();
      expect(dir.listSync().whereType<File>()
          .where((f) => p.basename(f.path).startsWith('sikaya_backup_')), hasLength(1)); // tetap 1
    });

    test('instalasi baru: tanpa backup, langsung v2', () async {
      final path = p.join(dir.path, 'baru.db');
      final db2 = await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi);
      expect(await db2.getVersion(), 2); // dbVersion
      await db2.close();
      expect(dir.listSync().where((f) => p.basename(f.path).contains('backup')), isEmpty);
    });
  });
}
