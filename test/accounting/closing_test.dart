// Tutup buku lewat repository (bagian B): D5 pada file DB nyata (dengan backup),
// periode terkunci menolak tulis, tutup buku ganda ditolak.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'helpers.dart';

/// Skenario campuran E7 (helpers.skenarioCampuran) lewat DB; id 1..9 sama dengan helper.
Future<void> seedCampuran(AccountingRepository repo) async {
  await repo.insertFixedAsset(const FixedAssetModel(
      name: 'Peralatan kandang', readyDate: '2026-01-10', lifeMonths: 12)); // id 1
  for (final t in skenarioCampuran()) {
    await repo.insertTransaction(TransactionModel(
      txType: t.type,
      amount: t.amount,
      date: t.date.toIso8601String().substring(0, 10),
      qty: t.qty,
      item: t.item,
      refId: t.refId,
      assetId: t.assetId,
    ));
  }
}

Future<int> count(Database db, String table, [String where = '1']) async =>
    (await db.rawQuery('SELECT COUNT(*) AS n FROM $table WHERE $where')).first['n'] as int;

void main() {
  sqfliteFfiInit();
  final jan31 = d('2026-01-31');
  final hariIni = d('2026-03-01');
  late Directory dir;
  late String path;
  late Database db;
  late AccountingRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sikaya_tutup');
    path = p.join(dir.path, 'sikaya.db');
    db = await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi);
    repo = AccountingRepository(() async => db,
        backup: () => DatabaseHelper.copyDatabaseFile(path, 'tutupbuku'));
    await seedCampuran(repo);
    await repo.insertTransaction(
        const TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-02-10'));
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('D5: tutup buku Jan tidak menghapus transaksi; total aset dan saldo laba sama', () async {
    final before = (await repo.loadReport(asOf: jan31)).report;
    final beforeFeb = (await repo.loadReport(asOf: d('2026-02-28'))).report;
    final idsBefore = (await repo.transactions()).map((t) => t.id).toSet();
    expect(idsBefore, hasLength(10)); // 9 skenario + jual Feb

    final res = await repo.closeBook(jan31, today: hariIni);

    final after = (await repo.loadReport(asOf: jan31)).report;
    expect(after.totalAset, before.totalAset);
    expect(after.totalAset, 8700000); // 7.000.000 + 600.000 + 1.100.000
    expect(after.saldoLaba, before.saldoLaba); // 2.200.000
    expect(after.labaBersih, before.labaBersih); // 2.500.000
    expect(after.balanced, isTrue);
    expect((await repo.loadReport(asOf: d('2026-02-28'))).report.totalAset,
        beforeFeb.totalAset); // posisi sesudah periode juga tidak berubah

    final rows = await repo.transactions();
    expect(rows.map((t) => t.id).toSet().containsAll(idsBefore), isTrue); // tidak ada yang hilang
    expect(rows, hasLength(11)); // 10 + 1 entri tutup buku
    final entri = rows.singleWhere((t) => t.txType == TxType.tutupBuku);
    expect(entri.id, res.closingTxId);
    expect(entri.amount, 2500000); // laba Jan: 3.000.000 - 400.000 - 100.000
    expect(entri.date, '2026-01-31');

    final arsip = (await db.query('period_closings')).single;
    expect(arsip['closed_until'], '2026-01-31');
    expect(arsip['closing_tx_id'], res.closingTxId);
    expect(arsip['laba_bersih'], 2500000);
    expect(arsip['total_aset'], 8700000);
    expect(arsip['saldo_laba'], 2200000); // 2.500.000 - prive 300.000
    expect(await repo.lockedUntil(), jan31);

    // backup file dibuat SEBELUM entri tutup buku: berisi 10 transaksi tanpa tutup_buku
    expect(p.basename(res.backupPath), startsWith('sikaya_backup_tutupbuku_'));
    final cadangan = await databaseFactoryFfi.openDatabase(res.backupPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false));
    expect(await count(cadangan, 'transactions'), 10);
    expect(await count(cadangan, 'period_closings'), 0);
    await cadangan.close();
  });

  group('periode terkunci menolak tambah/ubah/hapus', () {
    setUp(() => repo.closeBook(jan31, today: hariIni));

    test('tambah: tanggal <= kunci ditolak dengan pesan jelas, sesudahnya diterima', () async {
      final jan = const TransactionModel(txType: TxType.penjualanTunai, amount: 1, date: '2026-01-31');
      final e = await repo.insertTransaction(jan).then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<PeriodLockedException>());
      expect(pesanPeriodeTerkunci(e as PeriodLockedException),
          allOf(contains('2026-01-31'), contains('retur/transaksi pembalik')));
      await repo.insertTransaction(
          const TransactionModel(txType: TxType.penjualanTunai, amount: 1, date: '2026-02-01'));
      expect(await count(db, 'transactions', "date <= '2026-01-31'"), 10); // 9 + tutup buku
    });

    test('beli aset bertanggal terkunci: aset tidak ikut dibuat', () async {
      final spec = txFormSpecs[TxType.beliAsetTetap]!;
      final draft = buildDraft(spec, FormInput({
        FieldKey.namaAset: 'Motor',
        FieldKey.tanggal: '2026-01-20',
        FieldKey.nominal: 1000000,
        FieldKey.sumberBayar: PaymentSource.kas,
        FieldKey.umurBulan: 96,
      }));
      await expectLater(repo.insertDraft(draft), throwsA(isA<PeriodLockedException>()));
      expect(await count(db, 'fixed_assets'), 1); // hanya peralatan kandang
    });

    test('ubah: transaksi Jan, atau memindah transaksi Feb ke Jan, ditolak', () async {
      final jual = txFormSpecs[TxType.penjualanTunai]!;
      TxDraft ubah(int id, String date) => buildDraft(
          jual, FormInput({FieldKey.tanggal: date, FieldKey.nominal: 999}), id: id);
      await expectLater(repo.updateDraft(ubah(4, '2026-02-15')), throwsA(isA<PeriodLockedException>()));
      await expectLater(repo.updateDraft(ubah(10, '2026-01-15')), throwsA(isA<PeriodLockedException>()));
      expect((await repo.transactionById(4))!.amount, 300000); // prive Jan tetap
      expect((await repo.transactionById(10))!.date, '2026-02-10'); // jual Feb tetap
      await repo.updateDraft(ubah(10, '2026-02-11')); // Feb -> Feb boleh
      expect((await repo.transactionById(10))!.amount, 999);
    });

    test('hapus transaksi Jan dan entri tutup buku ditolak; baris tetap ada', () async {
      await expectLater(repo.deleteTransaction(5), throwsA(isA<PeriodLockedException>()));
      final entri = (await repo.transactions()).singleWhere((t) => t.txType == TxType.tutupBuku);
      await expectLater(repo.deleteTransaction(entri.id!), throwsA(isA<PeriodLockedException>()));
      expect(await count(db, 'transactions'), 11);
    });

    test('koreksi lewat retur di periode berjalan diterima; laporan Jan tidak berubah', () async {
      final ref = await repo.rujukan();
      final draft = buildDraft(returFormSpec, FormInput({
        FieldKey.transaksiAsal: 4, // prive Jan 300.000
        FieldKey.tanggal: '2026-02-05',
        FieldKey.nominal: 100000,
      }, rujukan: {for (final r in ref.retur) r.id: r}));
      final row = (await repo.transactionById(await repo.insertDraft(draft)))!;
      expect(row.perluDitinjau, isFalse);
      expect((await repo.loadReport(asOf: jan31)).report.prive, 300000); // Jan terkunci tetap
      expect((await repo.loadReport(asOf: d('2026-02-28'))).report.prive, 200000); // 300.000 - 100.000
    });
  });

  group('tutup buku ganda / tidak sah ditolak', () {
    test('periode yang sama dua kali, atau tanggal sebelum kunci, ditolak', () async {
      await repo.closeBook(jan31, today: hariIni);
      await expectLater(repo.closeBook(jan31, today: hariIni), throwsA(isA<ClosingRejectedException>()));
      await expectLater(repo.closeBook(d('2026-01-15'), today: hariIni),
          throwsA(isA<ClosingRejectedException>()));
      expect(await count(db, 'period_closings'), 1);
      expect(await count(db, 'transactions', "tx_type = 'tutup_buku'"), 1);

      // periode berikutnya boleh; laba hanya Feb: 500.000 - penyusutan 100.000
      final feb = await repo.closeBook(d('2026-02-28'), today: hariIni);
      expect(feb.preview.from, d('2026-02-01'));
      expect(feb.preview.report.labaBersih, 400000);
      expect(feb.preview.report.saldoLaba, 2600000); // 2.200.000 + 400.000
    });

    test('tanggal sesudah hari ini, backup gagal, atau ada perlu_ditinjau: tidak ada yang dicatat', () async {
      await expectLater(repo.closeBook(d('2026-03-02'), today: hariIni),
          throwsA(isA<ClosingRejectedException>()));

      final tanpaBackup = AccountingRepository(() async => db,
          backup: () async => throw const FileSystemException('disk penuh'));
      await expectLater(tanpaBackup.closeBook(jan31, today: hariIni), throwsA(isA<FileSystemException>()));

      await repo.insertTransaction(const TransactionModel(
          txType: TxType.pakaiPersediaan, amount: 0, date: '2026-01-25', qty: 999, item: StockItem.pakan));
      await expectLater(repo.closeBook(jan31, today: hariIni), throwsA(isA<ClosingRejectedException>()));

      expect(await count(db, 'period_closings'), 0);
      expect(await count(db, 'transactions', "tx_type = 'tutup_buku'"), 0);
      expect(await repo.lockedUntil(), isNull);
    });
  });
}
