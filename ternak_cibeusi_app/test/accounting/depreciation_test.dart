// Penyusutan: garis lurus, tanpa residu, bulan penuh mulai bulan "siap dipakai".
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';

import 'helpers.dart';

FixedAsset aset(int cost, int life, String ready) => FixedAsset(
    id: 1, name: 'x', cost: cost, readyDate: d(ready), lifeMonths: life);

void main() {
  test('total penyusutan seluruh umur == harga perolehan (habis dibagi)', () {
    final s = depreciationSchedule(aset(1200000, 12, '2026-01-10'));
    expect(s.length, 12); // umur 12 bulan
    expect(s.every((x) => x == 100000), isTrue); // 1.200.000 / 12
    expect(s.fold(0, (a, b) => a + b), 1200000); // 100.000 x 12
  });

  test('total penyusutan == harga perolehan (tidak habis dibagi): sisa di bulan terakhir', () {
    // 1.000.000 / 12 = 83.333 x 11 = 916.663; bulan ke-12 = 83.337
    final s = depreciationSchedule(aset(1000000, 12, '2026-01-10'));
    expect(s.sublist(0, 11).every((x) => x == 83333), isTrue); // 1.000.000/12 = 83.333,33 -> 83.333
    expect(s.last, 83337); // 1.000.000 - 83.333 x 11
    expect(s.fold(0, (a, b) => a + b), 1000000); // 83.333 x 11 + 83.337
  });

  test('total == harga perolehan untuk banyak kombinasi harga/umur', () {
    for (final cost in [1, 7, 999, 1000001, 12345679, 5000000000]) {
      for (final life in [1, 3, 7, 12, 48, 120]) {
        final s = depreciationSchedule(aset(cost, life, '2026-01-01'));
        expect(s.fold(0, (a, b) => a + b), cost, reason: '$cost/$life'); // jumlah jadwal = harga perolehan
            expect(s.every((x) => x >= 0), isTrue, reason: '$cost/$life');
      }
    }
  });

  test('pembulatan setengah ke atas pada susutan bulanan; berhenti saat akumulasi = harga', () {
    // 5/3 = 1,67 -> 2
    expect(depreciationSchedule(aset(5, 3, '2026-01-01')), [2, 2, 1]); // 2, 2, sisa 5 - 2 x 2
    // 7/12 = 0,58 -> 1; akumulasi 7 tercapai di bulan ke-7, bulan 8-12 = 0
    expect(depreciationSchedule(aset(7, 12, '2026-01-01')),
        [1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]); // 1 x 7 bulan = 7, lalu 0
    // 1.000.006/12 = 83.333,83 -> 83.334
    final s = depreciationSchedule(aset(1000006, 12, '2026-01-01'));
    expect(s.first, 83334); // 1.000.006/12 = 83.333,83 -> 83.334
    expect(s.last, 83332); // 1.000.006 - 83.334 x 11
  });

  test('akumulasi: bulan siap-pakai dihitung penuh walau siap pakai tgl 31', () {
    final a = aset(1200000, 12, '2026-01-31');
    expect(accumulatedDepreciation(a, d('2026-01-31')), 100000); // 100.000 x 1 bulan (Jan)
    expect(accumulatedDepreciation(a, d('2026-02-01')), 200000); // 100.000 x 2 bulan (Jan-Feb)
    expect(accumulatedDepreciation(a, d('2026-12-15')), 1200000); // 100.000 x 12 bulan (Jan-Des)
  });

  test('akumulasi: nol sebelum siap dipakai, berhenti = harga perolehan setelah umur habis', () {
    final a = aset(1000000, 12, '2026-03-05');
    expect(accumulatedDepreciation(a, d('2026-02-28')), 0); // 0 bulan (siap pakai Mar)
    expect(accumulatedDepreciation(a, d('2027-02-28')), 1000000); // 83.333 x 11 + 83.337 (Mar 2026-Feb 2027)
    expect(accumulatedDepreciation(a, d('2030-01-01')), 1000000); // dibatasi harga perolehan 1.000.000
  });

  test('akumulasi: bulan terakhir mengambil sisa pembulatan', () {
    final a = aset(1000000, 12, '2026-01-10');
    expect(accumulatedDepreciation(a, d('2026-11-30')), 83333 * 11); // 83.333 x 11 bulan (Jan-Nov)
    expect(accumulatedDepreciation(a, d('2026-12-31')), 1000000); // 916.663 + sisa 83.337
  });

  test('tanah (lifeMonths null) tidak disusutkan', () {
    final tanah = FixedAsset(
        id: 2, name: 'Tanah', cost: 50000000, readyDate: d('2026-01-01'));
    expect(accumulatedDepreciation(tanah, d('2040-01-01')), 0); // tanah tidak disusutkan
  });

  test('tanggal siap dipakai berbeda dari tanggal beli: susut mulai bulan siap pakai', () {
    // dibeli Jan, siap pakai Mar: Jan-Feb belum disusutkan
    final a = aset(1200000, 12, '2026-03-01');
    final txs = [tx(1, '2026-01-10', TxType.beliAsetTetap, amount: 1200000, assetId: 1)];
    final jan = buildReport(txs, [a], asOf: d('2026-02-28'));
    expect(jan.akumulasiPenyusutan, 0); // 0 bulan (siap pakai Mar)
    final mar = buildReport(txs, [a], asOf: d('2026-03-31'));
    expect(mar.akumulasiPenyusutan, 100000); // 1.200.000/12 x 1 bulan (Mar)
  });
}
