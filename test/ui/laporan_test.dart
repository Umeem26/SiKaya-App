// S3: layar laporan dua lapis pada 360dp, huruf 1,0x dan 2,0x; angka yang tampil
// di Ringkasan sama dengan yang tampil di laporan resmi; Ekspor PDF membagikan satu file.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/laporan_resmi_page.dart';
import 'package:ternak_cibeusi_app/report_page.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import '../accounting/closing_test.dart' show seedCampuran;
import 'alur_catat_test.dart' show catat;
import 'ui_helpers.dart';

final hariIni = DateTime(2026, 2, 15);

Future<AccountingRepository> repoLaporan() async {
  SharedPreferences.setMockInitialValues({'owner_name': 'Peternakan Ayam Cibeusi Makmur Sejahtera'});
  final repo = await repoUji();
  await seedCampuran(repo);
  for (final t in const [
    TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-02-10'),
    TransactionModel(
        txType: TxType.bebanOperasional, amount: 200000, date: '2026-02-12', expenseKind: ExpenseKind.listrikAir),
    TransactionModel(txType: TxType.penjualanKredit, amount: 300000, date: '2026-02-14'),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, qty: 999, item: StockItem.obat, date: '2026-02-14'),
  ]) {
    await repo.insertTransaction(t);
  }
  return repo;
}

/// "−Rp1.234" / "(Rp1.234)" -> -1234; "+Rp5" -> 5.
int angka(String s) {
  final n = int.parse(s.replaceAll(RegExp(r'[^0-9]'), ''));
  return s.contains('−') || s.contains('(') ? -n : n;
}

Future<int> nilaiKartu(WidgetTester tester, String judul) async {
  final k = find.byWidgetPredicate((w) => w is KartuAngka && w.judul == judul);
  await gulirKe(tester, k);
  return angka(tester.widget<KartuAngka>(k).nilai);
}

Future<int> nilaiBaris(WidgetTester tester, String label) async {
  final b = find.byWidgetPredicate((w) => w is BarisLaporan && w.label == label);
  await gulirKe(tester, b);
  return angka(tester.widget<BarisLaporan>(b.first).nilai);
}

Finder tab(String judul) => find.descendant(of: find.byType(TabGeser), matching: find.text(judul));

Future<void> bukaTab(WidgetTester tester, String judul) async {
  await ketuk(tester, tab(judul));
}

void main() {
  for (final skala in skalaUji) {
    testWidgets('Ringkasan 360dp huruf ${skala}x: pilihan waktu, 8 angka berpenjelasan', (tester) async {
      final repo = await repoLaporan();
      await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: skala);
      await semuaTerlihat(tester, [
        'Bulan ini', 'Bulan lalu', 'Tahun ini', 'Pilih tanggal',
        '1 Februari 2026 s.d. 15 Februari 2026',
        '1 catatan perlu dicek',
        'Uang masuk', '+Rp500.000',
        'Uang keluar', '−Rp200.000',
        'Untung', 'Rp500.000',
        'Uang kas di akhir waktu ini', 'Rp7.300.000',
        'Nilai stok', 'Rp600.000',
        'Nilai kandang & peralatan', 'Rp1.000.000',
        'Utang', 'Rp1.500.000',
        'Piutang', 'Rp300.000',
      ]);
      // Setiap angka punya satu kalimat penjelasan.
      for (final k in tester.widgetList<KartuAngka>(find.byType(KartuAngka))) {
        expect(k.keterangan, isNotEmpty, reason: k.judul);
      }
      final lihat = find.ancestor(of: find.text('Lihat laporan resmi'), matching: find.byType(FilledButton));
      expect(tester.getSize(lihat).height, greaterThanOrEqualTo(56));
      dalamLebar(tester, lihat);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Laporan resmi 360dp huruf ${skala}x: 4 tab, istilah SAK EMKM, Ekspor PDF', (tester) async {
      final repo = await repoLaporan();
      await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: skala);
      await tester.tap(find.text('Lihat laporan resmi'));
      await tester.pumpAndSettle();
      expect(find.byType(LaporanResmiPage), findsOneWidget);

      final isi = {
        'Posisi Keuangan': ['Laporan Posisi Keuangan', 'Per 15 Februari 2026', 'Kas', 'Rp7.300.000',
          'Akumulasi penyusutan', '(Rp200.000)', 'JUMLAH ASET', 'JUMLAH LIABILITAS DAN EKUITAS'],
        'Laba Rugi': ['Laporan Laba Rugi', 'Untuk periode 1 Februari 2026 s.d. 15 Februari 2026',
          'Pendapatan penjualan', 'Beban listrik dan air', 'Beban penyusutan', 'LABA (RUGI) BERSIH'],
        'CaLK': ['Catatan atas Laporan Keuangan', '1. Umum', '3. Persediaan', '7. Ikhtisar Akun Penting', '8. Batasan'],
        'Perubahan Ekuitas': ['Laporan Perubahan Ekuitas', 'Modal disetor awal', 'Saldo laba awal',
          'Saldo laba akhir', 'JUMLAH EKUITAS'],
      };
      for (final MapEntry(key: judul, value: teks) in isi.entries) {
        await bukaTab(tester, judul);
        // Area ketuk tab = InkWell TabBar di sekeliling pil.
        final tombol = find.ancestor(of: tab(judul), matching: find.byType(InkWell)).first;
        expect(tester.getSize(tombol).height, greaterThanOrEqualTo(48), reason: 'tab $judul');
        dalamLebar(tester, tab(judul));
        await semuaTerlihat(tester, teks);
        await semuaTerlihat(tester, ['Perlu ditinjau']);
        cekTinggiKontrol(tester);
        if (skala == 2.0) await cekAreaSentuh(tester);
      }
      final ekspor = find.ancestor(of: find.text('Ekspor PDF'), matching: find.byType(FilledButton));
      expect(tester.getSize(ekspor).height, greaterThanOrEqualTo(56));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('angka di layar Ringkasan = angka di layar laporan resmi (data sama)', (tester) async {
    final repo = await repoLaporan();
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 1.0);
    for (final p in ['Bulan ini', 'Bulan lalu', 'Tahun ini']) {
      await ketuk(tester, find.text(p));
      final kartuLaba = find.byWidgetPredicate((w) => w is KartuAngka && (w.judul == 'Untung' || w.judul == 'Rugi'));
      await gulirKe(tester, kartuLaba);
      final k = tester.widget<KartuAngka>(kartuLaba);
      final untung = k.judul == 'Rugi' ? -angka(k.nilai) : angka(k.nilai);
      final ringkasan = {
        'Kas': await nilaiKartu(tester, 'Uang kas di akhir waktu ini'),
        'Piutang usaha': await nilaiKartu(tester, 'Piutang'),
        'Utang': await nilaiKartu(tester, 'Utang'),
        'Nilai buku aset tetap': await nilaiKartu(tester, 'Nilai kandang & peralatan'),
      };
      final stok = await nilaiKartu(tester, 'Nilai stok');

      await tester.tap(find.text('Lihat laporan resmi'));
      await tester.pumpAndSettle();
      for (final MapEntry(key: label, value: n) in ringkasan.entries) {
        expect(await nilaiBaris(tester, label), n, reason: '$p: $label');
      }
      var stokResmi = 0;
      for (final l in ['Persediaan Pakan', 'Persediaan Obat & Vitamin', 'Persediaan Ternak']) {
        stokResmi += await nilaiBaris(tester, l);
      }
      expect(stokResmi, stok, reason: '$p: stok');
      await bukaTab(tester, 'Laba Rugi');
      expect(await nilaiBaris(tester, 'LABA (RUGI) BERSIH'), untung, reason: '$p: untung');
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ekspor PDF: satu file dibagikan dengan nama periode', (tester) async {
    final repo = await repoLaporan();
    final dibagikan = <(Uint8List, String)>[];
    await pasangHalaman(
        tester,
        ReportPage(repo: repo, hariIni: hariIni, bagikan: (pdf, nama) async => dibagikan.add((pdf, nama))),
        skala: 1.0);
    await ketuk(tester, find.text('Bulan lalu'));
    await tester.tap(find.text('Lihat laporan resmi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekspor PDF'));
    await tester.pumpAndSettle();
    expect(dibagikan, hasLength(1));
    expect(dibagikan.single.$2, 'laporan_keuangan_2026-01-01_2026-01-31.pdf');
    expect(String.fromCharCodes(dibagikan.single.$1.take(4)), '%PDF');
    expect(find.text('Ekspor PDF'), findsOneWidget); // tombol kembali aktif
  });

  testWidgets('alur: catat lewat UI -> tab Laporan menampilkan angka baru', (tester) async {
    final repo = await repoLaporan();
    aturLayar(tester, 1.0);
    await tester.pumpWidget(MaterialApp(theme: temaSikaya(), home: HalamanUtama(repo: repo, hariIni: hariIni)));
    await tester.pumpAndSettle();
    await catat(tester, 'Jual, dibayar tunai', nominal: 1000000);
    await catat(tester, 'Bayar bunga pinjaman', nominal: 50000);

    await tester.tap(find.text('Laporan').last);
    await tester.pumpAndSettle();
    expect(await nilaiKartu(tester, 'Uang masuk'), 1500000);
    expect(await nilaiKartu(tester, 'Uang keluar'), -250000);
    expect(await nilaiKartu(tester, 'Untung'), 1450000); // 500.000 + 1.000.000 - 50.000
    expect(await nilaiKartu(tester, 'Uang kas di akhir waktu ini'), 8250000);

    await tester.tap(find.text('Lihat laporan resmi'));
    await tester.pumpAndSettle();
    await bukaTab(tester, 'Laba Rugi');
    expect(await nilaiBaris(tester, 'Beban bunga'), 50000);
    expect(await nilaiBaris(tester, 'LABA (RUGI) BERSIH'), 1450000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laporan resmi: kop nama usaha + periode, band judul, total bergaris ganda', (tester) async {
    final repo = await repoLaporan();
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 1.0);
    await tester.tap(find.text('Lihat laporan resmi'));
    await tester.pumpAndSettle();
    // Kop: nama usaha, judul, periode (rata tengah) di dalam kertas laporan.
    for (final s in ['Peternakan Ayam Cibeusi Makmur Sejahtera', 'Laporan Posisi Keuangan', 'Per 15 Februari 2026']) {
      expect(tester.widget<Text>(find.text(s)).textAlign, TextAlign.center, reason: s);
    }
    expect(find.descendant(of: find.byType(BandJudul), matching: find.text('ASET')), findsOneWidget);
    expect(find.descendant(of: find.byType(BandJudul), matching: find.text('LIABILITAS')), findsOneWidget);
    await gulirKe(tester, find.byType(BarisTotal));
    final total = find.byWidgetPredicate((w) => w is BarisTotal && w.label == 'JUMLAH ASET');
    expect(total, findsOneWidget);
    // Garis atas + dua garis bawah (garis ganda).
    expect(find.descendant(of: total, matching: find.byType(Divider)), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
