// Kasus tepi (disetujui). Angka hitung manual juga ada di PLAN-FASE1.md bagian 4.
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';

import 'helpers.dart';

void main() {
  final jan31 = d('2026-01-31');

  group('K1 retur = transaksi pembalik', () {
    test('retur parsial 200.000 dari penjualan tunai 1.000.000', () {
      final r = buildReport([
        tx(1, '2026-01-05', TxType.penjualanTunai, amount: 1000000),
        tx(2, '2026-01-08', TxType.penjualanTunai, amount: 200000, reversalOf: 1),
      ], [], asOf: jan31);
      expect(r.pendapatan, 800000); // 1.000.000 - retur 200.000
      expect(r.kas, 800000); // 1.000.000 - 200.000
      expect(r.labaBersih, 800000); // 800.000 - beban 0
      expect(r.perluDitinjau, isEmpty);
    });

    test('retur melebihi nilai asli (1.000.001 dari 1.000.000) -> perlu_ditinjau, dikeluarkan', () {
      final r = buildReport([
        tx(1, '2026-01-05', TxType.penjualanTunai, amount: 1000000),
        tx(2, '2026-01-08', TxType.penjualanTunai, amount: 1000001, reversalOf: 1),
      ], [], asOf: jan31);
      expect(r.pendapatan, 1000000); // 1.000.000 - retur 0 (1.000.001 dikeluarkan)
      expect(r.kas, 1000000); // 1.000.000 - 0
      expect(r.perluDitinjau.map((f) => f.txId), [2]); // id retur
      expect(r.perluDitinjau.single.reason, ReviewReason.returMelebihiAsli);
    });
  });

  group('K2 pembayaran sebagian piutang', () {
    final jual = tx(1, '2026-01-05', TxType.penjualanKredit, amount: 3000000);

    test('terima 1.000.000 lalu 2.000.000 dari piutang 3.000.000', () {
      final r1 = buildReport([
        jual,
        tx(2, '2026-01-10', TxType.terimaPiutang, amount: 1000000, refId: 1),
      ], [], asOf: jan31);
      expect(r1.piutang, 2000000); // 3.000.000 - 1.000.000
      expect(r1.kas, 1000000); // 0 + 1.000.000
      expect(r1.pendapatan, 3000000); // penjualan kredit 3.000.000

      final r2 = buildReport([
        jual,
        tx(2, '2026-01-10', TxType.terimaPiutang, amount: 1000000, refId: 1),
        tx(3, '2026-01-20', TxType.terimaPiutang, amount: 2000000, refId: 1),
      ], [], asOf: jan31);
      expect(r2.piutang, 0); // 3.000.000 - 1.000.000 - 2.000.000
      expect(r2.kas, 3000000); // 1.000.000 + 2.000.000
      expect(r2.labaBersih, 3000000); // 3.000.000 - beban 0 (pelunasan bukan pendapatan)
    });

    test('pelunasan melebihi sisa (3.000.001 dari 3.000.000) -> perlu_ditinjau, dikeluarkan', () {
      final r = buildReport([
        jual,
        tx(2, '2026-01-10', TxType.terimaPiutang, amount: 3000001, refId: 1),
      ], [], asOf: jan31);
      expect(r.piutang, 3000000); // 3.000.000 - 0 (3.000.001 dikeluarkan)
      expect(r.kas, 0); // 0 + 0
      expect(r.perluDitinjau.single.reason, ReviewReason.pelunasanMelebihiPiutang);
    });
  });

  group('K3 kematian ternak = beban kerugian ternak (rata-rata tertimbang)', () {
    test('200 ekor total 2.200.000 (100@10.000 + 100@12.000), mati 4 ekor', () {
      // rata-rata 11.000/ekor; kerugian 4 x 11.000 = 44.000 = 2.200.000*4/200
      final r = buildReport([
        tx(1, '2026-01-02', TxType.beliPersediaanTunai,
            amount: 1000000, qty: 100, item: StockItem.ternak),
        tx(2, '2026-01-03', TxType.beliPersediaanTunai,
            amount: 1200000, qty: 100, item: StockItem.ternak),
        tx(3, '2026-01-10', TxType.kematianTernak, qty: 4, item: StockItem.ternak),
      ], [], asOf: jan31);
      expect(r.beban[ExpenseKind.kerugianTernak], 44000); // 2.200.000 x 4/200
      expect(r.persediaan[StockItem.ternak], 2156000); // 2.200.000 - 44.000
      expect(r.labaBersih, -44000); // 0 - 44.000
    });
  });

  group('K4 pemakaian melebihi stok (diterima, ditandai perlu_ditinjau)', () {
    test('stok pakan 100 kg Rp1.000.000, pakai 120 kg', () {
      // transaksi diterima/disimpan, tetapi dikeluarkan dari laporan:
      // beban 0, persediaan tetap 1.000.000 (tidak minus), peringatan memuat id dan hitungan.
      final r = buildReport([
        tx(1, '2026-01-02', TxType.beliPersediaanTunai,
            amount: 1000000, qty: 100, item: StockItem.pakan),
        tx(2, '2026-01-10', TxType.pakaiPersediaan, qty: 120, item: StockItem.pakan),
      ], [], asOf: jan31);
      expect(r.beban[ExpenseKind.pakan] ?? 0, 0); // pemakaian 120 kg dikeluarkan: beban 0
      expect(r.persediaan[StockItem.pakan], 1000000); // 1.000.000 - 0
      expect(r.perluDitinjau.length, 1); // 1 transaksi (id 2)
      expect(r.perluDitinjau.single.txId, 2); // id pemakaian
      expect(r.perluDitinjau.single.reason, ReviewReason.pemakaianMelebihiStok);
      expect(r.perluDitinjau.single.detail, contains('120')); // qty diminta 120
      expect(r.perluDitinjau.single.detail, contains('100')); // qty tersedia 100
      expect(r.balanced, isTrue);
    });
  });

  group('K5 periode terkunci (ditolak)', () {
    final lock = d('2026-01-31');

    test('tulis pada/sebelum tanggal kunci ditolak, sesudahnya diterima', () {
      expect(() => checkWrite(date: d('2026-01-31'), lockedUntil: lock),
          throwsA(isA<PeriodLockedException>()));
      expect(() => checkWrite(date: d('2026-01-05'), lockedUntil: lock),
          throwsA(isA<PeriodLockedException>()));
      expect(() => checkWrite(date: d('2026-02-01'), lockedUntil: lock),
          returnsNormally);
      expect(() => checkWrite(date: d('2026-01-05'), lockedUntil: null),
          returnsNormally);
    });

    test('edit/hapus: tanggal lama atau baru di periode terkunci ditolak', () {
      expect(
          () => checkEdit(
              oldDate: d('2026-01-15'), newDate: d('2026-02-15'), lockedUntil: lock),
          throwsA(isA<PeriodLockedException>()));
      expect(
          () => checkEdit(
              oldDate: d('2026-02-15'), newDate: d('2026-01-15'), lockedUntil: lock),
          throwsA(isA<PeriodLockedException>()));
      expect(
          () => checkEdit(
              oldDate: d('2026-02-15'), newDate: d('2026-02-20'), lockedUntil: lock),
          returnsNormally);
    });

    test('transaksi ditolak tidak mengubah laporan terkunci (laba Jan tetap 2.500.000)', () {
      final r = buildReport(skenarioCampuran(), [peralatan], asOf: jan31);
      expect(r.labaBersih, 2500000); // 3.000.000 - 400.000 - 100.000
      expect(r.totalAset, 8700000); // 7.000.000 + 600.000 + 1.100.000
    });
  });

  group('K6 urutan hari yang sama = menurut id', () {
    // id 10 beli 100kg 1.000.000; id 11 beli 100kg 2.000.000; id 12 pakai 100kg (semua 2026-01-05).
    // Menurut id: total 3.000.000/200kg -> pakai 100kg = 1.500.000; sisa 1.500.000 (100kg).
    // Bila pakai (id 12) diproses sebelum beli id 11: beban 1.000.000 (salah).
    test('urutan list diacak tidak mengubah hasil', () {
      final a = tx(10, '2026-01-05', TxType.beliPersediaanTunai,
          amount: 1000000, qty: 100, item: StockItem.pakan);
      final b = tx(11, '2026-01-05', TxType.beliPersediaanTunai,
          amount: 2000000, qty: 100, item: StockItem.pakan);
      final c = tx(12, '2026-01-05', TxType.pakaiPersediaan,
          qty: 100, item: StockItem.pakan);
      for (final urut in [
        [a, b, c],
        [c, a, b],
        [b, c, a],
      ]) {
        final r = buildReport(urut, [], asOf: jan31);
        expect(r.beban[ExpenseKind.pakan], 1500000); // (1.000.000 + 2.000.000) x 100/200
        expect(r.persediaan[StockItem.pakan], 1500000); // 3.000.000 - 1.500.000
        expect(r.perluDitinjau, isEmpty);
      }
    });

    test('pakai berid lebih kecil dari beli di hari sama -> melebihi stok', () {
      final r = buildReport([
        tx(9, '2026-01-05', TxType.pakaiPersediaan, qty: 100, item: StockItem.pakan),
        tx(10, '2026-01-05', TxType.beliPersediaanTunai,
            amount: 1000000, qty: 100, item: StockItem.pakan),
      ], [], asOf: jan31);
      expect(r.perluDitinjau.single.reason, ReviewReason.pemakaianMelebihiStok);
      expect(r.persediaan[StockItem.pakan], 1000000); // 0 + beli 1.000.000 (pakai id 9 dikeluarkan)
    });
  });

  test('penjualan bertanggal lampau: laporan tanggal lampau ikut berubah', () {
    // Penjualan 500.000 bertanggal 2026-01-05 diinput belakangan (id 10).
    final txs = [
      ...skenarioCampuran(),
      tx(10, '2026-01-05', TxType.penjualanTunai, amount: 500000),
    ];
    final r = buildReport(txs, [peralatan], asOf: jan31);
    expect(r.pendapatan, 3500000); // 3.000.000 + 500.000
    expect(r.labaBersih, 3000000); // 3.500.000 - 400.000 - 100.000
    expect(r.kas, 7500000); // 7.000.000 + 500.000
    expect(r.balanced, isTrue);
    final awal = buildReport(txs, [peralatan], asOf: d('2026-01-05'));
    expect(awal.pendapatan, 500000); // hanya penjualan 2026-01-05
  });

  group('peringatan perlu_ditinjau (jumlah transaksi + total nilai)', () {
    test('tiga transaksi ditandai: tidak dihitung, peringatan memuat jumlah dan total', () {
      final r = buildReport([
        tx(1, '2026-01-02', TxType.beliPersediaanTunai,
            amount: 1000000, qty: 100, item: StockItem.pakan),
        tx(2, '2026-01-10', TxType.pakaiPersediaan, qty: 120, item: StockItem.pakan),
        tx(3, '2026-01-11', TxType.penjualanTunai, amount: 1000000),
        tx(4, '2026-01-12', TxType.penjualanTunai, amount: 1000001, reversalOf: 3),
        tx(5, '2026-01-13', TxType.penjualanKredit, amount: 3000000),
        tx(6, '2026-01-14', TxType.terimaPiutang, amount: 3000001, refId: 5),
      ], [], asOf: jan31);
      expect(r.perluDitinjau.map((f) => f.txId), [2, 4, 6]); // pakai 120 > 100, retur > asli, terima > piutang
      expect(r.perluDitinjau[0].nilai, 1200000); // taksiran 1.000.000 x 120/100
      expect(r.perluDitinjau[1].nilai, 1000001); // nilai retur
      expect(r.perluDitinjau[2].nilai, 3000001); // nilai pelunasan
      final w = r.peringatanTinjau!;
      expect(w.jumlahTransaksi, 3); // id 2, 4, 6
      expect(w.totalNilai, 5200002); // 1.200.000 + 1.000.001 + 3.000.001
      expect(w.pesan, contains('3 transaksi')); // jumlahTransaksi 3
      expect(w.pesan, contains('Rp5.200.002')); // totalNilai 5.200.002
      // angka laporan tanpa transaksi yang ditandai
      expect(r.pendapatan, 4000000); // 1.000.000 + 3.000.000
      expect(r.bebanTotal, 0); // pemakaian dikeluarkan
      expect(r.kas, 0); // -1.000.000 + 1.000.000
      expect(r.piutang, 3000000); // 3.000.000 - 0
      expect(r.persediaan[StockItem.pakan], 1000000); // 1.000.000 - 0
      expect(r.balanced, isTrue);
    });

    test('buku kas juga mengeluarkan transaksi yang ditandai (D3 tetap berlaku)', () {
      final txs = [
        tx(3, '2026-01-11', TxType.penjualanTunai, amount: 1000000),
        tx(4, '2026-01-12', TxType.penjualanTunai, amount: 1000001, reversalOf: 3),
      ];
      expect(cashBookBalance(txs, asOf: jan31), 1000000); // 1.000.000 - 0 (retur ditandai)
      expect(buildReport(txs, [], asOf: jan31).kas, 1000000); // sama dengan buku kas
    });

    test('pemakaian saat stok kosong: nilai taksiran 0', () {
      final r = buildReport([
        tx(1, '2026-01-02', TxType.pakaiPersediaan, qty: 5, item: StockItem.obat),
      ], [], asOf: jan31);
      expect(r.peringatanTinjau!.jumlahTransaksi, 1); // id 1
      expect(r.peringatanTinjau!.totalNilai, 0); // stok 0: tidak ada biaya rata-rata
    });

    test('tanpa transaksi ditandai: peringatan null', () {
      final r = buildReport(skenarioCampuran(), [peralatan], asOf: jan31);
      expect(r.peringatanTinjau, isNull);
    });
  });

  test('roundHalfAwayFromZero: setengah menjauhi nol, simetris untuk negatif', () {
    expect(roundHalfAwayFromZero(1, 2), 1); // 0,5 -> 1
    expect(roundHalfAwayFromZero(3, 2), 2); // 1,5 -> 2
    expect(roundHalfAwayFromZero(1000, 3), 333); // 333,33 -> 333
    expect(roundHalfAwayFromZero(667, 2), 334); // 333,5 -> 334
    expect(roundHalfAwayFromZero(5, 3), 2); // 1,67 -> 2
    expect(roundHalfAwayFromZero(-1, 2), -1); // -0,5 -> -1
    expect(roundHalfAwayFromZero(-3, 2), -2); // -1,5 -> -2
    expect(roundHalfAwayFromZero(-7, 5), -1); // -1,4 -> -1
    expect(roundHalfAwayFromZero(-5, 3), -2); // -1,67 -> -2
    expect(roundHalfAwayFromZero(-1000, 3), -333); // -333,33 -> -333
    expect(roundHalfAwayFromZero(-667, 2), -334); // -333,5 -> -334
    expect(roundHalfAwayFromZero(-6, 3), -2); // -2 tepat
    expect(() => roundHalfAwayFromZero(1, 0), throwsArgumentError);
  });

  test('simetris: f(n) + f(-n) == 0 untuk banyak n/d', () {
    for (final den in [1, 2, 3, 7, 12, 200]) {
      for (var n = -1000; n <= 1000; n += 7) {
        // f(n) + f(-n) = 0 (pembulatan tidak menyisakan selisih antara transaksi dan pembaliknya)
        expect(roundHalfAwayFromZero(n, den) + roundHalfAwayFromZero(-n, den), 0,
            reason: '$n/$den');
      }
    }
  });

  group('transaksi + retur penuh = efek tepat nol', () {
    // Pembanding: skenario campuran E7 tanpa transaksi tambahan.
    final base = buildReport(skenarioCampuran(), [peralatan], asOf: jan31);
    final cases = <String, List<AcctTx>>{
      'penjualan_tunai': [
        tx(20, '2026-01-21', TxType.penjualanTunai, amount: 333333),
        tx(21, '2026-01-22', TxType.penjualanTunai, amount: 333333, reversalOf: 20),
      ],
      'penjualan_kredit': [
        tx(20, '2026-01-21', TxType.penjualanKredit, amount: 777777),
        tx(21, '2026-01-22', TxType.penjualanKredit, amount: 777777, reversalOf: 20),
      ],
      'terima_piutang': [
        tx(20, '2026-01-21', TxType.penjualanKredit, amount: 500000),
        tx(21, '2026-01-22', TxType.terimaPiutang, amount: 500000, refId: 20),
        tx(22, '2026-01-23', TxType.terimaPiutang, amount: 500000, reversalOf: 21),
        tx(23, '2026-01-24', TxType.penjualanKredit, amount: 500000, reversalOf: 20),
      ],
      'beban_operasional (kas)': [
        tx(20, '2026-01-21', TxType.bebanOperasional,
            amount: 123457, expense: ExpenseKind.listrikAir),
        tx(21, '2026-01-22', TxType.bebanOperasional,
            amount: 123457, expense: ExpenseKind.listrikAir, reversalOf: 20),
      ],
      'beban_operasional (utang)': [
        tx(20, '2026-01-21', TxType.bebanOperasional,
            amount: 99999, expense: ExpenseKind.tenagaKerja, onCredit: true),
        tx(21, '2026-01-22', TxType.bebanOperasional,
            amount: 99999, expense: ExpenseKind.tenagaKerja, onCredit: true, reversalOf: 20),
      ],
      'beban_bunga': [
        tx(20, '2026-01-21', TxType.bebanBunga, amount: 15001),
        tx(21, '2026-01-22', TxType.bebanBunga, amount: 15001, reversalOf: 20),
      ],
      'setor_modal': [
        tx(20, '2026-01-21', TxType.setorModal, amount: 1000001),
        tx(21, '2026-01-22', TxType.setorModal, amount: 1000001, reversalOf: 20),
      ],
      'prive': [
        tx(20, '2026-01-21', TxType.prive, amount: 33333),
        tx(21, '2026-01-22', TxType.prive, amount: 33333, reversalOf: 20),
      ],
      'terima_pinjaman': [
        tx(20, '2026-01-21', TxType.terimaPinjaman, amount: 2500000),
        tx(21, '2026-01-22', TxType.terimaPinjaman, amount: 2500000, reversalOf: 20),
      ],
      'bayar_cicilan_pokok': [
        tx(20, '2026-01-21', TxType.bayarCicilanPokok, amount: 250000),
        tx(21, '2026-01-22', TxType.bayarCicilanPokok, amount: 250000, reversalOf: 20),
      ],
      'penjualan_tunai, retur dua kali (1 + 333.332)': [
        tx(20, '2026-01-21', TxType.penjualanTunai, amount: 333333),
        tx(21, '2026-01-22', TxType.penjualanTunai, amount: 1, reversalOf: 20),
        tx(22, '2026-01-23', TxType.penjualanTunai, amount: 333332, reversalOf: 20),
      ],
    };
    cases.forEach((name, extra) {
      test(name, () {
        final txs = [...skenarioCampuran(), ...extra];
        final r = buildReport(txs, [peralatan], asOf: jan31);
        // setiap angka = angka E7 + transaksi - retur = angka E7 + 0
        expect(r.kas, base.kas); // 7.000.000 + x - x
        expect(r.piutang, base.piutang); // 0 + x - x
        expect(r.utang, base.utang); // 1.500.000 + x - x
        expect(r.modalDisetor, base.modalDisetor); // 5.000.000 + x - x
        expect(r.prive, base.prive); // 300.000 + x - x
        expect(r.pendapatan, base.pendapatan); // 3.000.000 + x - x
        expect(r.beban, base.beban); // {pakan 400.000, penyusutan 100.000} + x - x
        expect(r.labaBersih, base.labaBersih); // 2.500.000 + x - x
        expect(r.saldoLaba, base.saldoLaba); // 2.200.000 + x - x
        expect(r.totalAset, base.totalAset); // 8.700.000 + x - x
        expect(cashBookBalance(txs, asOf: jan31), base.kas); // 7.000.000 + x - x
        expect(r.perluDitinjau, isEmpty);
        expect(r.balanced, isTrue);
      });
    });
  });

  test('cashBookSummary: masuk - keluar = saldo buku kas = kas laporan', () {
    final txs = skenarioCampuran();
    final c = cashBookSummary(txs, asOf: jan31);
    expect(c.masuk, 10000000); // setor 5.000.000 + pinjam 2.000.000 + terima piutang 3.000.000
    expect(c.keluar, 3000000); // cicilan 500.000 + prive 300.000 + pakan 1.000.000 + peralatan 1.200.000
    expect(c.saldo, 7000000); // 10.000.000 - 3.000.000
    expect(c.saldo, buildReport(txs, [peralatan], asOf: jan31).kas);
  });
}
