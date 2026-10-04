// Skenario E1-E7 dari ACCOUNTING-SPEC-SAK-EMKM.md, angka dihitung manual.
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';

import 'helpers.dart';

void main() {
  final jan31 = d('2026-01-31');

  test('16 tipe transaksi memuat 15 kode dari spec bagian C', () {
    const spec = [
      'penjualan_tunai', 'penjualan_kredit', 'terima_piutang',
      'beli_persediaan_tunai', 'beli_persediaan_kredit', 'pakai_persediaan',
      'beban_operasional', 'beli_aset_tetap', 'penyusutan', 'setor_modal',
      'prive', 'terima_pinjaman', 'bayar_cicilan_pokok', 'beban_bunga',
      'tutup_buku',
    ];
    final codes = TxType.values.map((t) => t.code).toSet();
    expect(codes.containsAll(spec), isTrue);
    expect(TxType.values.length, 16); // 15 tipe spec C + kematian_ternak = 16
  });

  test('E1: beli pakan 1.000.000 tunai (100 kg), pakai 40 kg', () {
    final r = buildReport([
      tx(1, '2026-01-05', TxType.beliPersediaanTunai,
          amount: 1000000, qty: 100, item: StockItem.pakan),
      tx(2, '2026-01-06', TxType.pakaiPersediaan, qty: 40, item: StockItem.pakan),
    ], [], asOf: jan31);
    expect(r.beban[ExpenseKind.pakan], 400000); // 1.000.000 x 40/100
    expect(r.persediaan[StockItem.pakan], 600000); // 1.000.000 - 400.000
    expect(r.labaBersih, -400000); // pendapatan 0 - beban 400.000
    expect(r.kas, -1000000); // 0 - beli tunai 1.000.000
  });

  test('E1b: rata-rata tertimbang 100kg@10.000 + 100kg@12.000, pakai 50 kg', () {
    // total 2.200.000 / 200 kg; pakai 50 kg = 550.000; sisa 1.650.000
    final r = buildReport([
      tx(1, '2026-01-05', TxType.beliPersediaanTunai,
          amount: 1000000, qty: 100, item: StockItem.pakan),
      tx(2, '2026-01-06', TxType.beliPersediaanTunai,
          amount: 1200000, qty: 100, item: StockItem.pakan),
      tx(3, '2026-01-07', TxType.pakaiPersediaan, qty: 50, item: StockItem.pakan),
    ], [], asOf: jan31);
    expect(r.beban[ExpenseKind.pakan], 550000); // (1.000.000 + 1.200.000) x 50/200
    expect(r.persediaan[StockItem.pakan], 1650000); // 2.200.000 - 550.000
  });

  test('E1c: pembulatan 3 kg total Rp1.000 dipakai 1+1+1 -> 333+334+333 = 1.000', () {
    // 1000*1/3=333,33->333 (sisa 667); 667*1/2=333,5->334 (sisa 333); 333*1/1=333 (sisa 0)
    final r = buildReport([
      tx(1, '2026-01-05', TxType.beliPersediaanTunai,
          amount: 1000, qty: 3, item: StockItem.obat),
      tx(2, '2026-01-06', TxType.pakaiPersediaan, qty: 1, item: StockItem.obat),
      tx(3, '2026-01-07', TxType.pakaiPersediaan, qty: 1, item: StockItem.obat),
      tx(4, '2026-01-08', TxType.pakaiPersediaan, qty: 1, item: StockItem.obat),
    ], [], asOf: jan31);
    expect(r.beban[ExpenseKind.obat], 1000); // 333 + 334 + 333
    expect(r.persediaan[StockItem.obat], 0); // 1.000 - 1.000
  });

  test('E2: setor modal 5.000.000 -> kas +5.000.000, laba 0', () {
    final r = buildReport(
        [tx(1, '2026-01-02', TxType.setorModal, amount: 5000000)], [],
        asOf: jan31);
    expect(r.kas, 5000000); // 0 + setor 5.000.000
    expect(r.labaBersih, 0); // setoran modal bukan pendapatan: 0 - 0
    expect(r.pendapatan, 0); // tidak ada penjualan
    expect(r.modalDisetor, 5000000); // setor 5.000.000
  });

  test('E3: pinjam 2.000.000, cicilan pokok 500.000 -> utang 1.500.000, laba 0', () {
    final r = buildReport([
      tx(1, '2026-01-02', TxType.terimaPinjaman, amount: 2000000),
      tx(2, '2026-01-03', TxType.bayarCicilanPokok, amount: 500000),
    ], [], asOf: jan31);
    expect(r.utang, 1500000); // 2.000.000 - 500.000
    expect(r.kas, 1500000); // 2.000.000 - 500.000
    expect(r.labaBersih, 0); // pokok pinjaman/cicilan bukan pendapatan/beban
  });

  test('E4: prive 300.000 -> ekuitas -300.000, laba 0', () {
    final r = buildReport(
        [tx(1, '2026-01-02', TxType.prive, amount: 300000)], [],
        asOf: jan31);
    expect(r.prive, 300000); // prive 300.000
    expect(r.saldoLaba, -300000); // laba 0 - prive 300.000
    expect(r.labaBersih, 0); // prive bukan beban: 0 - 0
    expect(r.bebanTotal, 0); // tidak ada beban
    expect(r.kas, -300000); // 0 - 300.000
  });

  test('E5: beli peralatan 1.200.000 umur 12 bln -> penyusutan 100.000/bulan', () {
    final txs = [
      tx(1, '2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: 1),
    ];
    final jan = buildReport(txs, [peralatan], asOf: jan31);
    expect(jan.asetTetapBruto, 1200000); // harga perolehan 1.200.000
    expect(jan.akumulasiPenyusutan, 100000); // 1.200.000/12 x 1 bulan (Jan, bulan siap pakai, penuh)
    expect(jan.asetTetapNeto, 1100000); // 1.200.000 - 100.000
    expect(jan.beban[ExpenseKind.penyusutan], 100000); // 1.200.000/12 x 1 bulan
    expect(jan.bebanTotal, 100000); // penyusutan 100.000 + pembelian 0 (bukan beban)
    expect(jan.pendapatan, 0); // tidak ada penjualan

    final feb = buildReport(txs, [peralatan],
        asOf: d('2026-02-28'), from: d('2026-02-01'));
    expect(feb.beban[ExpenseKind.penyusutan], 100000); // akumulasi Feb 200.000 - akumulasi Jan 100.000

    final habis = buildReport(txs, [peralatan], asOf: d('2026-12-31'));
    expect(habis.asetTetapNeto, 0); // 1.200.000 - 100.000 x 12 bulan (Jan-Des)

    final lewat = buildReport(txs, [peralatan],
        asOf: d('2027-03-31'), from: d('2027-01-01'));
    expect(lewat.asetTetapNeto, 0); // 1.200.000 - akumulasi maksimum 1.200.000
    expect(lewat.beban[ExpenseKind.penyusutan] ?? 0, 0); // akumulasi Mar 2027 1.200.000 - akumulasi Des 2026 1.200.000
  });

  test('E6: jual ayam 3.000.000 kredit lalu terima 3.000.000', () {
    final jual = [tx(1, '2026-01-12', TxType.penjualanKredit, amount: 3000000)];
    final r1 = buildReport(jual, [], asOf: jan31);
    expect(r1.pendapatan, 3000000); // penjualan kredit 3.000.000
    expect(r1.piutang, 3000000); // 0 + 3.000.000
    expect(r1.kas, 0); // belum ada uang masuk

    final r2 = buildReport([
      ...jual,
      tx(2, '2026-01-20', TxType.terimaPiutang, amount: 3000000, refId: 1),
    ], [], asOf: jan31);
    expect(r2.pendapatan, 3000000); // 3.000.000 + pelunasan 0 (bukan pendapatan)
    expect(r2.labaBersih, 3000000); // 3.000.000 - beban 0
    expect(r2.piutang, 0); // 3.000.000 - 3.000.000
    expect(r2.kas, 3000000); // 0 + 3.000.000
  });

  test('E7: campuran E1-E6, angka manual per 2026-01-31', () {
    final r = buildReport(skenarioCampuran(), [peralatan], asOf: jan31);
    expect(r.kas, 7000000); // 5.000.000 + 2.000.000 - 500.000 - 300.000 - 1.000.000 - 1.200.000 + 3.000.000
    expect(r.piutang, 0); // 3.000.000 - 3.000.000
    expect(r.persediaan[StockItem.pakan], 600000); // 1.000.000 - 1.000.000 x 40/100
    expect(r.asetTetapNeto, 1100000); // 1.200.000 - 1.200.000/12 x 1
    expect(r.totalAset, 8700000); // 7.000.000 + 0 + 600.000 + 1.100.000
    expect(r.utang, 1500000); // 2.000.000 - 500.000
    expect(r.modalDisetor, 5000000); // setor 5.000.000
    expect(r.pendapatan, 3000000); // penjualan kredit 3.000.000
    expect(r.bebanTotal, 500000); // pakan 400.000 + penyusutan 100.000
    expect(r.labaBersih, 2500000); // 3.000.000 - 500.000
    expect(r.saldoLaba, 2200000); // 2.500.000 - prive 300.000
    expect(r.totalLiabilitasEkuitas, 8700000); // utang 1.500.000 + modal 5.000.000 + saldo laba 2.200.000
    expect(r.balanced, isTrue);
    expect(r.perluDitinjau, isEmpty);
  });
}
