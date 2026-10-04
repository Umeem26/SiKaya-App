// Hapus beli_aset_tetap (bagian C): dialog menyebut asetnya ikut terhapus, dan
// memang itu yang dilakukan repository.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'db_helpers.dart';
import 'helpers.dart';

void main() {
  sqfliteFfiInit();

  test('pesan hapus menyebut aset ikut terhapus hanya untuk beli aset tetap', () async {
    final db = await openMemoryDb();
    addTearDown(db.close);
    final repo = AccountingRepository(() async => db);
    final spec = txFormSpecs[TxType.beliAsetTetap]!;
    final id = await repo.insertDraft(buildDraft(
        spec,
        FormInput({
          FieldKey.namaAset: 'Kandang panggung',
          FieldKey.tanggal: '2026-03-01',
          FieldKey.nominal: 12000000,
          FieldKey.sumberBayar: PaymentSource.kas,
          FieldKey.umurBulan: 120,
        })));
    final beli = (await repo.transactionById(id))!;
    final aset = await repo.fixedAssetById(beli.assetId!);

    expect(hapusIkutAset(beli), isTrue);
    final pesan = pesanHapus(beli, aset: aset);
    expect(pesan, contains('"Kandang panggung" IKUT TERHAPUS'));
    expect(pesan, contains('Laporan Posisi Keuangan'));

    final jual = (await repo.transactionById(await repo.insertTransaction(
        const TransactionModel(txType: TxType.penjualanTunai, amount: 1000, date: '2026-03-02'))))!;
    expect(hapusIkutAset(jual), isFalse);
    expect(pesanHapus(jual), isNot(contains('Aset tetap')));

    // Perilaku sesuai pesan: transaksi dan aset hilang, laporan tanpa aset tetap.
    await repo.deleteTransaction(id);
    expect(await repo.fixedAssets(), isEmpty);
    final r = (await repo.loadReport(asOf: d('2026-12-31'))).report;
    expect(r.asetTetapBruto, 0);
    expect(r.akumulasiPenyusutan, 0);
  });
}
