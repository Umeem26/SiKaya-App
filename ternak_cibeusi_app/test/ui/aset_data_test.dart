// DataAset (tab Aset dan ringkasan Beranda) = angka mesin: total sama dengan
// Laporan Posisi Keuangan, riwayat penyusutan dari jadwal mesin, jumlah stok dari
// catatan yang sah, stok menipis dari pemakaian 30 hari.
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/aset_data.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'aset_uji.dart';
import 'ui_helpers.dart';

void main() {
  test('total aset dan stok = Report mesin per tanggal yang sama', () async {
    final repo = await repoAsetUji();
    final d = await muatDataAset(repo, hariIni: hariAset);
    final r = (await repo.loadReport(asOf: hariAset)).report;
    expect(d.nilaiBukuAsetTetap, r.asetTetapNeto);
    expect(d.hargaPerolehanAsetTetap, r.asetTetapBruto);
    expect(d.nilaiPersediaan, r.persediaanTotal);
    expect(d.asetTetap.fold<int>(0, (a, x) => a + x.hargaPerolehan), r.asetTetapBruto);
    expect(d.asetTetap.fold<int>(0, (a, x) => a + x.akumulasi), r.akumulasiPenyusutan);
    for (final i in StockItem.values) {
      expect(d.stokDari(i).nilai, r.persediaan[i] ?? 0, reason: i.name);
    }
  });

  test('aset tetap: nilai buku, sisa umur, riwayat penyusutan bulanan', () async {
    final d = await muatDataAset(await repoAsetUji(), hariIni: hariAset);
    final kandang = d.asetTetap.singleWhere((a) => a.nama == 'Kandang panggung bambu');
    // Maret s.d. Oktober = 8 bulan x 100.000.
    expect(kandang.akumulasi, 800000);
    expect(kandang.nilaiBuku, 5200000);
    expect(kandang.sisaBulan, 52);
    expect(kandang.riwayat, hasLength(8));
    expect(kandang.riwayat.first.bulan, DateTime(2026, 3));
    expect(kandang.riwayat.last.bulan, DateTime(2026, 10));
    expect(kandang.riwayat.last.akumulasi, kandang.akumulasi);
    expect(kandang.riwayat.last.nilaiBuku, kandang.nilaiBuku);
    expect(kandang.idBeli, isNotNull);

    final lahan = d.asetTetap.singleWhere((a) => a.nama == 'Lahan belakang rumah');
    expect(lahan.disusutkan, isFalse);
    expect(lahan.sisaBulan, isNull);
    expect(lahan.riwayat, isEmpty);
    expect(lahan.nilaiBuku, 8000000);
  });

  test('jumlah stok dari catatan sah; obat tanpa stok tidak dihitung; pakan menipis', () async {
    final d = await muatDataAset(await repoAsetUji(), hariIni: hariAset);
    expect(d.jumlahTernak, 30); // 1000 - 950 keluar dijual - 20 mati
    expect(d.stokDari(StockItem.ternak).nilai, 30 * 7000);
    final pakan = d.stokDari(StockItem.pakan);
    expect(pakan.jumlah, 300);
    expect(pakan.nilai, 300 * 7000);
    expect(pakan.pakai30Hari, 1700);
    expect(pakan.cukupHari, 5);
    expect(pakan.menipis, isTrue);
    final obat = d.stokDari(StockItem.obat);
    expect(obat.jumlah, 0);
    expect(obat.pernahDibeli, isFalse);
    expect(obat.menipis, isFalse, reason: 'belum pernah dibeli: bukan "menipis"');
    expect(d.menipis.map((s) => s.item), [StockItem.pakan]);
    expect(d.stokDari(StockItem.ternak).menipis, isFalse, reason: 'ternak keluar karena dijual');
  });

  test('jumlahStok: perlu dicek dan tanggal sesudah batas diabaikan', () {
    const rows = [
      TransactionModel(txType: TxType.beliPersediaanTunai, amount: 100, date: '2026-01-01', qty: 10, item: StockItem.pakan),
      TransactionModel(
          txType: TxType.pakaiPersediaan, amount: 0, date: '2026-01-02', qty: 50, item: StockItem.pakan, perluDitinjau: true),
      TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-01-03', qty: 4, item: StockItem.pakan),
      TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, date: '2026-02-01', qty: 5, item: StockItem.pakan),
    ];
    expect(jumlahStok(rows, DateTime(2026, 1, 31))[StockItem.pakan], 6);
  });

  test('tanpa catatan: adaData false, semua nol', () async {
    final d = await muatDataAset(await repoUji(), hariIni: hariAset);
    expect(d.adaData, isFalse);
    expect(d.asetTetap, isEmpty);
    expect(d.nilaiBukuAsetTetap + d.nilaiPersediaan + d.jumlahTernak, 0);
  });
}
