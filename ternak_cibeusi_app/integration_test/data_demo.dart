// Data demo FIKTIF untuk pratinjau tampilan (integration_test/pratinjau_test.dart):
// peternakan ayam pedaging contoh sejak Maret 2026, dimasukkan langsung lewat
// AccountingRepository (cepat, tanpa mengetik di form). Hanya ada di integration_test.
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

Future<void> isiDataDemo(AccountingRepository repo) async {
  Future<void> tx(TxType t, int nominal, String tgl,
          {int? qty, StockItem? item, ExpenseKind? beban, PaymentSource bayar = PaymentSource.kas, String ket = ''}) =>
      repo.insertTransaction(TransactionModel(
          txType: t,
          amount: nominal,
          date: tgl,
          qty: qty,
          item: item,
          expenseKind: beban,
          paymentSource: bayar,
          description: ket));
  Future<void> aset(String nama, int harga, String tgl, int? umur, {PaymentSource bayar = PaymentSource.kas}) =>
      repo.insertDraft(TxDraft(
        TransactionModel(txType: TxType.beliAsetTetap, amount: harga, date: tgl, paymentSource: bayar),
        asset: FixedAssetModel(name: nama, readyDate: tgl, lifeMonths: umur),
      ));

  // Maret: modal, pinjaman koperasi, kandang dan alat.
  await tx(TxType.setorModal, 30000000, '2026-03-01');
  await tx(TxType.terimaPinjaman, 5000000, '2026-03-01', ket: 'Koperasi contoh');
  await aset('Kandang panggung bambu', 6000000, '2026-03-02', 60);
  await aset('Tempat minum otomatis', 1200000, '2026-03-05', 24);
  await aset('Pemanas gasolec', 900000, '2026-08-10', 36, bayar: PaymentSource.utang);
  await aset('Lahan belakang rumah', 8000000, '2026-03-02', null);

  // September: bibit dan pakan.
  await tx(TxType.beliPersediaanTunai, 7000000, '2026-09-03', qty: 1000, item: StockItem.ternak);
  await tx(TxType.beliPersediaanKredit, 14000000, '2026-09-03', qty: 2000, item: StockItem.pakan);
  await tx(TxType.pakaiPersediaan, 0, '2026-09-30', qty: 1500, item: StockItem.pakan);

  // Oktober: panen dan jual, biaya, cicilan.
  await tx(TxType.pakaiPersediaan, 0, '2026-10-02', qty: 950, item: StockItem.ternak);
  await tx(TxType.penjualanTunai, 20000000, '2026-10-02');
  await tx(TxType.penjualanKredit, 12000000, '2026-10-02', ket: 'Bandar contoh');
  await tx(TxType.kematianTernak, 0, '2026-10-03', qty: 20, item: StockItem.ternak);
  await tx(TxType.beliPersediaanTunai, 300000, '2026-10-03', qty: 10, item: StockItem.obat);
  await tx(TxType.pakaiPersediaan, 0, '2026-10-03', qty: 4, item: StockItem.obat);
  await tx(TxType.pakaiPersediaan, 0, '2026-10-03', qty: 200, item: StockItem.pakan);
  await tx(TxType.bebanOperasional, 1500000, '2026-10-04', beban: ExpenseKind.tenagaKerja);
  await tx(TxType.bebanOperasional, 350000, '2026-10-04', beban: ExpenseKind.listrikAir, bayar: PaymentSource.utang);
  await tx(TxType.bayarCicilanPokok, 500000, '2026-10-04');
  await tx(TxType.prive, 1000000, '2026-10-04');
}
