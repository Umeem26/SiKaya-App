// CaLK otomatis (bagian D): isi mengikuti data (metode per aset, jumlah aset,
// saldo persediaan, kunci periode) dan angkanya sama dengan laporan.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/calk.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';

import 'closing_test.dart' show seedCampuran;
import 'helpers.dart';

String calk(List<AcctTx> txs, List<FixedAsset> assets, String asOf, {DateTime? locked}) =>
    calkText(buildCalk(
      txs: txs,
      assets: assets,
      report: buildReport(txs, assets, asOf: d(asOf)),
      asOf: d(asOf),
      lockedUntil: locked,
    ));

void main() {
  sqfliteFfiInit();
  final tanah = FixedAsset(id: 2, name: 'Tanah kandang', cost: 30000000, readyDate: d('2026-02-01'));
  final modal = tx(1, '2026-01-01', TxType.setorModal, amount: 50000000);
  final beliPeralatan = tx(7, '2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: 1);
  final beliTanah = tx(20, '2026-02-01', TxType.beliAsetTetap, amount: 30000000, assetId: 2);

  test('bagian wajib selalu ada: dasar SAK EMKM, rata-rata tertimbang, garis lurus, aset biologis, batasan', () {
    final t = calk([modal], const [], '2026-01-31');
    for (final s in [
      'SAK EMKM',
      'metode rata-rata tertimbang',
      'garis lurus tanpa nilai residu',
      'bulan penuh',
      'Aset Biologis (Kebijakan Manajemen)',
      'SAK EMKM tidak mengatur aset biologis',
      'Retur yang barangnya kembali ke stok belum didukung',
      'mengunci periode secara permanen',
    ]) {
      expect(t, contains(s));
    }
  });

  test('B7: pakan langsung jadi beban, alokasi ke ternak ditunda, laba bisa berfluktuasi', () {
    final t = calk([modal], const [], '2026-01-31');
    expect(t, contains('diakui langsung sebagai Beban Pakan'));
    expect(t, contains('ditunda sampai tersedia pencatatan per batch/siklus dan jumlah populasi'));
    expect(t, contains('laba per periode dapat berfluktuasi'));
  });

  test('jumlah dan metode aset mengikuti data', () {
    final kosong = calk([modal], [peralatan, tanah], '2026-01-05');
    expect(kosong, contains('Belum ada aset tetap per 05-01-2026.'));

    final satu = calk([modal, beliPeralatan, beliTanah], [peralatan, tanah], '2026-01-31');
    expect(satu, contains('1 aset (1 disusutkan garis lurus, 0 tidak disusutkan)'));
    expect(satu, contains('Peralatan kandang: Rp1.100.000 (garis lurus 12 bulan'));
    expect(satu, isNot(contains('Tanah kandang'))); // dibeli Februari

    final dua = calk([modal, beliPeralatan, beliTanah], [peralatan, tanah], '2026-03-31');
    expect(dua, contains('2 aset (1 disusutkan garis lurus, 1 tidak disusutkan)'));
    expect(dua, contains('Peralatan kandang: Rp900.000 (garis lurus 12 bulan'));
    expect(dua, contains('Tanah kandang: Rp30.000.000 (tidak disusutkan (tanah)'));
    expect(dua, contains('Harga perolehan Rp31.200.000, akumulasi penyusutan Rp300.000, '
        'nilai buku Rp30.900.000'));
  });

  test('persediaan dan kunci periode mengikuti data', () {
    expect(calk([modal], const [], '2026-01-31'), contains('Tidak ada saldo persediaan'));
    final txs = [
      modal,
      tx(2, '2026-01-02', TxType.beliPersediaanTunai, amount: 1000000, qty: 100, item: StockItem.pakan),
      tx(3, '2026-01-03', TxType.pakaiPersediaan, qty: 40, item: StockItem.pakan),
    ];
    final t = calk(txs, const [], '2026-01-31', locked: d('2026-01-31'));
    expect(t, contains('Persediaan Pakan: Rp600.000'));
    expect(t, isNot(contains('Persediaan Ternak:')));
    expect(t, isNot(contains('Tidak ada saldo persediaan')));
    expect(t, contains('Periode sampai 31-01-2026 sudah ditutup buku.'));
    expect(calk(txs, const [], '2026-01-31'), contains('Belum ada periode yang ditutup buku.'));
  });

  test('aset dari transaksi perlu ditinjau tidak ikut, sama dengan Posisi Keuangan', () {
    final ganda = tx(8, '2026-01-11', TxType.beliAsetTetap, amount: 5000000, assetId: 1); // dibeli dua kali
    final txs = [modal, beliPeralatan, ganda];
    final r = buildReport(txs, [peralatan], asOf: d('2026-01-31'));
    final aset = asetTercatat(txs, [peralatan], r, d('2026-01-31'));
    expect(aset, hasLength(1));
    expect(aset.fold<int>(0, (a, x) => a + x.aset.cost), r.asetTetapBruto);
    expect(calkText(buildCalk(txs: txs, assets: [peralatan], report: r, asOf: d('2026-01-31'))),
        contains('1 transaksi perlu ditinjau'));
  });

  test('lewat repository: angka ikhtisar sama dengan laporan', () async {
    final db = await DatabaseHelper.openAppDatabase(inMemoryDatabasePath, databaseFactoryFfi);
    addTearDown(db.close);
    final repo = AccountingRepository(() async => db);
    await seedCampuran(repo);
    final asOf = d('2026-01-31');
    final r = (await repo.loadReport(asOf: asOf)).report;
    final s = await repo.loadCalk(asOf: asOf, namaUsaha: 'Peternakan Cibeusi');
    final t = calkText(s);
    expect(t, contains('Laporan keuangan Peternakan Cibeusi'));
    final ikhtisar = {for (final x in s.singleWhere((x) => x.judul.contains('Ikhtisar')).rincian) x.label: x.nilai};
    expect(ikhtisar['Kas'], r.kas); // 7.000.000
    expect(ikhtisar['Saldo laba'], r.saldoLaba); // 2.200.000
    expect(ikhtisar['Laba (rugi) bersih periode'], 2500000);
    expect(t, contains('1 aset (1 disusutkan garis lurus, 0 tidak disusutkan)'));
  });
}
