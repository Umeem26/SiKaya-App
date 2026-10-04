// Cadangan (bagian B): ekspor lalu pulihkan menghasilkan laporan identik; file
// rusak / versi tidak dikenal / tabel kurang ditolak tanpa mengubah data.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/database/backup.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/database/schema.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'closing_test.dart' show seedCampuran;
import 'helpers.dart';

/// Semua angka laporan dalam satu string, untuk membandingkan "identik".
String sidikJari(Report r) => [
      r.kas, r.piutang, r.persediaan, r.asetTetapBruto, r.akumulasiPenyusutan,
      r.totalAset, r.utang, r.modalDisetor, r.prive, r.saldoLaba,
      r.totalLiabilitasEkuitas, r.balanced, r.pendapatan, r.beban, r.bebanTotal,
      r.labaBersih, r.perluDitinjau.map((f) => '${f.txId}:${f.reason}:${f.nilai}'),
    ].join('|');

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late String path;
  Database? db;
  late AccountingRepository repo;
  late BackupService svc;

  Future<Database> open() async => db ??= await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi);

  /// Laporan beberapa periode + daftar transaksi/aset + kunci periode.
  Future<String> keadaan() async {
    final out = <String>[];
    for (final (from, asOf) in [
      (null, '2026-01-31'),
      ('2026-02-01', '2026-02-28'),
      ('2026-01-01', '2027-12-31'),
    ]) {
      final r = await repo.loadReport(asOf: d(asOf), from: from == null ? null : d(from));
      out.add('${sidikJari(r.report)} kas=${r.kas.masuk}/${r.kas.keluar}');
    }
    out.add((await repo.transactions()).map((t) => t.toMap().toString()).join());
    out.add((await repo.fixedAssets()).map((a) => a.toMap().toString()).join());
    out.add('${await repo.lockedUntil()}');
    return out.join('\n');
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sikaya_cadangan');
    path = p.join(dir.path, 'sikaya.db');
    repo = AccountingRepository(open,
        backup: () => DatabaseHelper.copyDatabaseFile(path, 'tutupbuku'));
    svc = BackupService(
      open: open,
      close: () async {
        await db?.close();
        db = null;
      },
      factory: () => databaseFactoryFfi,
    );
    await seedCampuran(repo);
    await repo.insertTransaction(
        const TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-02-10'));
    await repo.closeBook(d('2026-01-31'), today: d('2026-03-01'));
  });
  tearDown(() async {
    await db?.close();
    db = null;
    await dir.delete(recursive: true);
  });

  test('nama file berstempel waktu dan versi skema', () {
    expect(backupFileName(DateTime(2026, 10, 4, 7, 5, 9)), 'SiKaya_cadangan_v${dbVersion}_20261004_070509.db');
  });

  test('ekspor lalu pulihkan: laporan, transaksi, aset, dan kunci periode identik', () async {
    final sebelum = await keadaan();
    final file = await svc.exportTo(p.join(dir.path, backupFileName(DateTime.now())));

    final isi = await svc.inspect(file);
    expect(isi.versi, dbVersion);
    expect(isi.transaksi, 11); // 9 skenario + jual Feb + entri tutup buku
    expect(isi.asetTetap, 1);
    expect(isi.tanggalAwal, '2026-01-02');
    expect(isi.tanggalAkhir, '2026-02-10');
    expect(isi.ditutupSampai, '2026-01-31');

    // Data berubah sesudah ekspor.
    await repo.insertTransaction(
        const TransactionModel(txType: TxType.prive, amount: 100000, date: '2026-02-20'));
    await repo.deleteTransaction(10); // jual Feb
    expect(await keadaan(), isNot(sebelum));
    final berubah = await keadaan();

    final hasil = await svc.restoreFrom(file);
    expect(hasil.dipulihkan.transaksi, 11);
    expect(await keadaan(), sebelum);
    expect((await repo.loadReport(asOf: d('2026-02-28'))).report.balanced, isTrue);
    expect(File('$path.pulihkan').existsSync(), isFalse);

    // Cadangan otomatis = data sebelum dipulihkan (bisa dipulihkan kembali).
    expect(p.basename(hasil.cadanganOtomatis), contains('_backup_sebelumpulih_'));
    expect((await svc.inspect(hasil.cadanganOtomatis)).transaksi, 11); // 11 + prive - jual
    await svc.restoreFrom(hasil.cadanganOtomatis);
    expect(await keadaan(), berubah);
  });

  group('file ditolak tanpa mengubah data', () {
    Future<void> ditolak(String file, Matcher pesan) async {
      final sebelum = await keadaan();
      final isiFolder = dir.listSync().map((e) => e.path).toSet();
      await expectLater(svc.inspect(file),
          throwsA(isA<BackupInvalidException>().having((e) => e.pesan, 'pesan', pesan)));
      await expectLater(svc.restoreFrom(file), throwsA(isA<BackupInvalidException>()));
      expect(await keadaan(), sebelum);
      expect(dir.listSync().map((e) => e.path).toSet(), isiFolder); // tanpa cadangan/sisa file
    }

    Future<String> dbLain(String nama, Future<void> Function(Database) ubah) async {
      final f = p.join(dir.path, 'lain', nama);
      final x = await DatabaseHelper.openAppDatabase(f, databaseFactoryFfi);
      await ubah(x);
      await x.close();
      return f;
    }

    test('bukan SQLite / kosong / tidak ada', () async {
      final acak = File(p.join(dir.path, 'lain', 'acak.db'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.generate(4096, (i) => (i * 37) % 256));
      await ditolak(acak.path, contains('bukan database SQLite'));
      final kosong = File(p.join(dir.path, 'lain', 'kosong.db'))..writeAsBytesSync([]);
      await ditolak(kosong.path, contains('bukan database SQLite'));
      await ditolak(p.join(dir.path, 'lain', 'tidakada.db'), contains('tidak ditemukan'));
    });

    test('file terpotong / halaman rusak', () async {
      final asli = await svc.exportTo(p.join(dir.path, 'lain.db'));
      final bytes = File(asli).readAsBytesSync();
      File(asli).deleteSync();
      final potong = File(p.join(dir.path, 'lain', 'potong.db'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
      await ditolak(potong.path, anything);

      final rusak = [...bytes];
      for (var i = 4096; i < rusak.length; i++) {
        rusak[i] = 0xAB; // semua halaman sesudah halaman pertama ditimpa
      }
      final f = File(p.join(dir.path, 'lain', 'rusak.db'))..writeAsBytesSync(rusak);
      await ditolak(f.path, anything);
    });

    test('versi skema tidak dikenal (lebih baru, v1, tanpa versi)', () async {
      await ditolak(await dbLain('baru.db', (x) => x.setVersion(dbVersion + 1)), contains('lebih baru'));
      await ditolak(await dbLain('v1.db', (x) => x.setVersion(1)), contains('versi lama'));
      await ditolak(await dbLain('nol.db', (x) => x.setVersion(0)), contains('versi skema tidak ada'));
    });

    test('tabel inti tidak ada', () async {
      await ditolak(await dbLain('kurang.db', (x) => x.execute('DROP TABLE period_closings')),
          contains('period_closings'));
    });

    test('baris tidak terbaca mesin (tx_type tidak dikenal)', () async {
      final f = await dbLain('aneh.db', (x) async {
        await x.execute('PRAGMA ignore_check_constraints = ON');
        await x.insert('transactions', {'tx_type': 'hibah', 'amount': 1, 'date': '2026-01-01'});
      });
      await ditolak(f, contains('tx_type tidak dikenal'));
    });
  });
}
