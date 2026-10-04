// Data uji aset (fiktif): kandang 60 bulan, lahan (tidak disusutkan), bibit,
// pakan menipis, satu pemakaian obat tanpa stok (perlu dicek). Hari uji 4 Okt 2026.
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'ui_helpers.dart';

final hariAset = DateTime(2026, 10, 4);

Future<void> isiAsetUji(AccountingRepository repo) async {
  Future<void> aset(String nama, int harga, String tgl, int? umur) => repo.insertDraft(TxDraft(
        TransactionModel(txType: TxType.beliAsetTetap, amount: harga, date: tgl),
        asset: FixedAssetModel(name: nama, readyDate: tgl, lifeMonths: umur),
      ));
  await repo.insertTransaction(const TransactionModel(txType: TxType.setorModal, amount: 30000000, date: '2026-03-01'));
  await aset('Kandang panggung bambu', 6000000, '2026-03-02', 60);
  await aset('Lahan belakang rumah', 8000000, '2026-03-02', null);
  for (final t in const [
    TransactionModel(
        txType: TxType.beliPersediaanTunai, amount: 7000000, date: '2026-09-03', qty: 1000, item: StockItem.ternak),
    TransactionModel(
        txType: TxType.beliPersediaanKredit, amount: 14000000, date: '2026-09-03', qty: 2000, item: StockItem.pakan),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-09-30', qty: 1500, item: StockItem.pakan),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-10-02', qty: 950, item: StockItem.ternak),
    TransactionModel(txType: TxType.kematianTernak, amount: 0, date: '2026-10-03', qty: 20, item: StockItem.ternak),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-10-03', qty: 200, item: StockItem.pakan),
    // Obat belum pernah dibeli: mesin menandai perlu dicek, tidak mengurangi apa pun.
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-10-03', qty: 999, item: StockItem.obat),
  ]) {
    await repo.insertTransaction(t);
  }
}

Future<AccountingRepository> repoAsetUji() async {
  final repo = await repoUji();
  await isiAsetUji(repo);
  return repo;
}
