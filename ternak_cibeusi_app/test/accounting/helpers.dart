import 'package:ternak_cibeusi_app/accounting/models.dart';

DateTime d(String s) => DateTime.parse(s);

AcctTx tx(
  int id,
  String date,
  TxType type, {
  int amount = 0,
  int? qty,
  StockItem? item,
  ExpenseKind? expense,
  bool onCredit = false,
  int? refId,
  int? reversalOf,
  int? assetId,
}) =>
    AcctTx(
      id: id,
      date: d(date),
      type: type,
      amount: amount,
      qty: qty,
      item: item,
      expense: expense,
      onCredit: onCredit,
      refId: refId,
      reversalOf: reversalOf,
      assetId: assetId,
    );

/// Peralatan Rp1.200.000, siap pakai 2026-01-10, umur 12 bulan (Rp100.000/bulan).
final peralatan = FixedAsset(
  id: 1,
  name: 'Peralatan kandang',
  cost: 1200000,
  readyDate: d('2026-01-10'),
  lifeMonths: 12,
);

/// Skenario E1-E6 digabung (E7). Semua bertanggal Januari 2026.
/// Hitung manual per 2026-01-31: kas 7.000.000; persediaan pakan 600.000;
/// aset tetap neto 1.100.000; total aset 8.700.000; utang 1.500.000;
/// modal 5.000.000; prive 300.000; laba 2.500.000 (3.000.000 - 400.000 - 100.000);
/// saldo laba 2.200.000; ekuitas 7.200.000; liabilitas+ekuitas 8.700.000.
List<AcctTx> skenarioCampuran() => [
      tx(1, '2026-01-02', TxType.setorModal, amount: 5000000),
      tx(2, '2026-01-03', TxType.terimaPinjaman, amount: 2000000),
      tx(3, '2026-01-04', TxType.bayarCicilanPokok, amount: 500000),
      tx(4, '2026-01-05', TxType.prive, amount: 300000),
      tx(5, '2026-01-06', TxType.beliPersediaanTunai,
          amount: 1000000, qty: 100, item: StockItem.pakan),
      tx(6, '2026-01-07', TxType.pakaiPersediaan, qty: 40, item: StockItem.pakan),
      tx(7, '2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: 1),
      tx(8, '2026-01-12', TxType.penjualanKredit, amount: 3000000),
      tx(9, '2026-01-20', TxType.terimaPiutang, amount: 3000000, refId: 8),
    ];
