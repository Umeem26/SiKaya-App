// Invarian D1-D5 (spec bagian D), diuji pada LAPORAN, bukan hanya fungsi hitung.
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';

import 'helpers.dart';

void main() {
  final jan31 = d('2026-01-31');

  test('D1: Aset = Liabilitas + Ekuitas di tiap tanggal laporan', () {
    for (final s in ['2026-01-05', '2026-01-10', '2026-01-20', '2026-01-31', '2026-06-30', '2027-03-31']) {
      final r = buildReport(skenarioCampuran(), [peralatan], asOf: d(s));
      expect(r.totalAset, r.totalLiabilitasEkuitas, reason: s);
      expect(r.balanced, isTrue, reason: s);
    }
  });

  test('D2: laba bersih sama dengan perubahan Saldo Laba (Jan -> Feb)', () {
    // Feb: jual tunai 500.000 (id 10), prive 100.000 (id 11), penyusutan Feb 100.000.
    // Laba Feb = 500.000 - 100.000 = 400.000. Saldo laba: Jan 2.200.000 -> Feb 2.500.000
    // (2.200.000 + 400.000 - prive Feb 100.000).
    final txs = [
      ...skenarioCampuran(),
      tx(10, '2026-02-10', TxType.penjualanTunai, amount: 500000),
      tx(11, '2026-02-15', TxType.prive, amount: 100000),
    ];
    final jan = buildReport(txs, [peralatan], asOf: jan31);
    final feb = buildReport(txs, [peralatan],
        asOf: d('2026-02-28'), from: d('2026-02-01'));
    expect(jan.labaBersih, 2500000); // 3.000.000 - pakan 400.000 - penyusutan 100.000
    expect(feb.labaBersih, 400000); // 500.000 - penyusutan Feb 100.000
    expect(jan.saldoLaba, 2200000); // 2.500.000 - prive 300.000
    expect(feb.saldoLaba, 2500000); // 2.200.000 + 400.000 - prive Feb 100.000
    expect(feb.saldoLaba, jan.saldoLaba + feb.labaBersih - 100000);
  });

  test('D3: saldo kas laporan = saldo buku kas', () {
    final txs = skenarioCampuran();
    final r = buildReport(txs, [peralatan], asOf: jan31);
    expect(r.kas, cashBookBalance(txs, asOf: jan31));
    expect(cashBookBalance(txs, asOf: jan31), 7000000); // 5.000.000 + 2.000.000 - 500.000 - 300.000 - 1.000.000 - 1.200.000 + 3.000.000
    // sebelum pelunasan (2026-01-19): 4.000.000
    expect(cashBookBalance(txs, asOf: d('2026-01-19')), 4000000); // 7.000.000 - pelunasan 3.000.000
  });

  test('D4: tipe berefek-laba-nol tidak mengubah laba (tidak dihitung dua kali)', () {
    final dasar = [
      tx(1, '2026-01-02', TxType.penjualanTunai, amount: 1000000),
      tx(2, '2026-01-03', TxType.beliPersediaanTunai,
          amount: 100000, qty: 10, item: StockItem.pakan),
    ];
    final labaDasar = buildReport(dasar, [], asOf: jan31).labaBersih;
    expect(labaDasar, 1000000); // penjualan 1.000.000 - beban 0 (pakan dibeli, belum dipakai)

    final nol = <AcctTx>[
      tx(20, '2026-01-10', TxType.beliPersediaanTunai,
          amount: 200000, qty: 20, item: StockItem.obat),
      tx(21, '2026-01-10', TxType.beliPersediaanKredit,
          amount: 300000, qty: 30, item: StockItem.pakan),
      tx(22, '2026-01-10', TxType.setorModal, amount: 400000),
      tx(23, '2026-01-10', TxType.prive, amount: 50000),
      tx(24, '2026-01-10', TxType.terimaPinjaman, amount: 600000),
      tx(25, '2026-01-10', TxType.bayarCicilanPokok, amount: 100000),
    ];
    for (final t in nol) {
      final r = buildReport([...dasar, t], [], asOf: jan31);
      expect(r.labaBersih, labaDasar, reason: t.type.code);
    }
    // terima_piutang (pelunasan) tidak menambah pendapatan
    final r = buildReport([
      ...dasar,
      tx(30, '2026-01-11', TxType.penjualanKredit, amount: 700000),
      tx(31, '2026-01-12', TxType.terimaPiutang, amount: 700000, refId: 30),
    ], [], asOf: jan31);
    expect(r.pendapatan, 1700000); // 1.000.000 + 700.000 + pelunasan 0
    // pembelian aset tetap tidak jadi beban; hanya penyusutan
    final a = buildReport([
      ...dasar,
      tx(40, '2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: 1),
    ], [peralatan], asOf: jan31);
    expect(a.bebanTotal, 100000); // penyusutan Jan 1.200.000/12; pembelian aset 0
  });

  test('D5: tutup buku tidak menghapus transaksi; total aset dan saldo laba sama', () {
    final txs = skenarioCampuran();
    final before = buildReport(txs, [peralatan], asOf: jan31);
    final closing = buildClosingEntry(before, id: 99, date: jan31);
    expect(closing.type, TxType.tutupBuku);
    final after = [...txs, closing];
    expect(after.length, txs.length + 1); // 9 transaksi + 1 entri tutup buku
    final r = buildReport(after, [peralatan], asOf: jan31);
    expect(r.totalAset, before.totalAset);
    expect(r.totalAset, 8700000); // 7.000.000 + 600.000 + 1.100.000 (sama dengan sebelum tutup buku)
    expect(r.saldoLaba, before.saldoLaba);
    expect(r.balanced, isTrue);
  });
}
