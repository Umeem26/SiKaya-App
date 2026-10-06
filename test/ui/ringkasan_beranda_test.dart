// Data Beranda dari loadReport: angka bulan berjalan sama dengan hitung manual.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/beranda_page.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import '../accounting/closing_test.dart' show seedCampuran;
import '../accounting/db_helpers.dart';
import '../accounting/helpers.dart';

void main() {
  sqfliteFfiInit();

  test('Februari: kas masuk/keluar bulan ini, untung bulan ini, perlu dicek', () async {
    final db = await openMemoryDb();
    addTearDown(db.close);
    final repo = AccountingRepository(() async => db);
    await seedCampuran(repo); // Januari: kas akhir 7.000.000
    for (final t in const [
      TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-02-10'),
      TransactionModel(
          txType: TxType.bebanOperasional, amount: 200000, date: '2026-02-12', expenseKind: ExpenseKind.listrikAir),
      TransactionModel(txType: TxType.penjualanKredit, amount: 300000, date: '2026-02-14'),
      TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, qty: 999, item: StockItem.obat, date: '2026-02-14'),
    ]) {
      await repo.insertTransaction(t);
    }

    final r = await muatRingkasanBeranda(repo, hariIni: DateTime(2026, 2, 15, 9, 30), namaUsaha: 'Cibeusi');
    expect(r.dari, d('2026-02-01'));
    expect(r.sampai, d('2026-02-15'));
    expect(r.uangMasuk, 500000); // penjualan kredit tidak lewat kas
    expect(r.uangKeluar, 200000);
    expect(r.kasSekarang, 7300000); // 7.000.000 + 500.000 - 200.000
    // 500.000 + 300.000 - 200.000 - penyusutan 100.000
    expect(r.labaBersih, 500000);
    expect(r.perluDitinjau!.jumlahTransaksi, 1); // pakai obat 999 tanpa stok
    expect(r.seimbang, isTrue);

    // Januari dari awal pencatatan: masuk = modal 5 jt + pinjaman 2 jt + piutang 3 jt.
    final jan = await muatRingkasanBeranda(repo, hariIni: d('2026-01-31'), namaUsaha: 'Cibeusi');
    expect(jan.uangMasuk, 10000000);
    expect(jan.uangKeluar, 3000000); // cicilan 0,5 + prive 0,3 + pakan 1 + peralatan 1,2
    expect(jan.labaBersih, 2500000);
    expect(jan.perluDitinjau, isNull);
  });
}
