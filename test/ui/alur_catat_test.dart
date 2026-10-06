// S2: alur dari UI sampai angka: catat lewat "Apa yang terjadi?", angka Beranda
// dan daftar catatan berubah benar; ubah dan hapus lewat detail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/beranda_page.dart';
import 'package:ternak_cibeusi_app/detail_catatan_page.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/ui/item_catatan.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import 'ui_helpers.dart';

final hariIni = DateTime(2026, 10, 4);

Future<AccountingRepository> pasangAplikasi(WidgetTester tester, {double skala = 1.0}) async {
  SharedPreferences.setMockInitialValues({'owner_name': 'Ternak Cibeusi'});
  final repo = await repoUji();
  aturLayar(tester, skala);
  await tester.pumpWidget(
      MaterialApp(theme: temaSikaya(), home: HalamanUtama(repo: repo, hariIni: hariIni)));
  await tester.pumpAndSettle();
  return repo;
}

Finder kartu(String judul) => find.ancestor(of: find.text(judul), matching: find.byType(KartuAngka));

/// Gulir ke kartu Beranda [judul], pastikan nilainya [nilai].
Future<void> cekKartu(WidgetTester tester, String judul, String nilai) async {
  await gulirKe(tester, kartu(judul));
  expect(find.descendant(of: kartu(judul), matching: find.text(nilai)), findsOneWidget, reason: judul);
}

/// Isi satu catatan dari tombol "Apa yang terjadi?" (halaman mana pun yang memilikinya).
Future<void> catat(WidgetTester tester, String jenis,
    {int? nominal, String? pilihan, int? jumlah, bool tutupPesan = false}) async {
  // Huruf sangat besar: tombol di Beranda ikut tergulir (tidak dipin).
  final tombol = find.text('Apa yang terjadi?').last;
  await tester.ensureVisible(tombol);
  await tester.pumpAndSettle();
  await tester.tap(tombol);
  await tester.pumpAndSettle();
  await ketuk(tester, find.text(jenis));
  if (pilihan != null) await ketuk(tester, find.text(pilihan));
  if (jumlah != null) {
    final f = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number).first;
    await gulirKe(tester, f);
    await tester.enterText(f, '$jumlah');
  }
  if (nominal != null) {
    final f = find.descendant(of: find.byType(InputRupiah), matching: find.byType(TextField));
    await gulirKe(tester, f);
    await tester.enterText(f, '$nominal');
  }
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
  if (tutupPesan) {
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
  }
  // Tunggu SnackBar hilang agar tidak menutupi tombol.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('catat jual, biaya, piutang, stok kurang -> angka Beranda benar', (tester) async {
    final repo = await pasangAplikasi(tester);
    await gulirKe(tester, find.text('Belum ada catatan. Tekan "Apa yang terjadi?" di bawah untuk mencatat.'));

    await catat(tester, 'Jual, dibayar tunai', nominal: 500000);
    await cekKartu(tester, 'Uang masuk', '+Rp500.000');
    await cekKartu(tester, 'Untung bulan ini', 'Rp500.000');

    await catat(tester, 'Bayar biaya operasional', pilihan: 'Listrik & air', nominal: 200000);
    await cekKartu(tester, 'Uang keluar', '−Rp200.000');
    await cekKartu(tester, 'Untung bulan ini', 'Rp300.000');
    await cekKartu(tester, 'Uang kas sekarang', 'Rp300.000');

    // Penjualan kredit: untung naik, uang masuk tidak.
    await catat(tester, 'Jual, belum dibayar (piutang)', nominal: 300000);
    await cekKartu(tester, 'Uang masuk', '+Rp500.000');
    await cekKartu(tester, 'Untung bulan ini', 'Rp600.000');

    // Pakai obat tanpa stok: tersimpan, perlu dicek, tidak mengubah angka.
    await catat(tester, 'Pakai stok / ternak keluar karena dijual',
        pilihan: 'Obat & vitamin', jumlah: 5, tutupPesan: true);
    await gulirKe(tester, find.text('1 catatan perlu dicek'));
    await cekKartu(tester, 'Untung bulan ini', 'Rp600.000');

    // Catatan terakhir di Beranda memakai komponen yang sama dengan daftar Catatan.
    final teks = await kumpulkanTeks(tester, find.byType(ItemCatatan));
    expect(teks, containsAll(['+Rp500.000', '−Rp200.000', 'Rp300.000', 'Tidak lewat kas',
        'Perlu dicek: Jumlah yang dipakai melebihi stok yang tercatat']));
    await semuaTerlihat(tester, ['Tidak lewat kas', 'Perlu dicek: Jumlah yang dipakai melebihi stok yang tercatat']);

    // Angka layar = angka mesin.
    final p = await repo.loadReport(asOf: hariIni, from: DateTime(2026, 10, 1));
    expect((p.kas.masuk, p.kas.keluar, p.report.labaBersih), (500000, 200000, 600000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ubah dan hapus lewat Catatan -> detail; Beranda ikut berubah', (tester) async {
    final repo = await pasangAplikasi(tester);
    await catat(tester, 'Jual, dibayar tunai', nominal: 500000);
    await catat(tester, 'Bayar biaya operasional', pilihan: 'Upah tenaga kerja', nominal: 200000);

    // Tab Catat (daftar catatan) -> ketuk penjualan -> Ubah nominal.
    await tester.tap(find.descendant(of: find.byType(NavigasiBawah), matching: find.text('Catat')));
    await tester.pumpAndSettle();
    await ketuk(tester, find.text('Jual, dibayar tunai'));
    expect(find.byType(DetailCatatanPage), findsOneWidget);
    await ketuk(tester, find.text('Ubah'));
    final rp = find.descendant(of: find.byType(InputRupiah), matching: find.byType(TextField));
    expect(tester.widget<TextField>(rp).controller!.text, '500.000');
    await tester.enterText(rp, '700000');
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailCatatanPage), findsOneWidget);
    expect(find.text('+Rp700.000'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Hapus biaya lewat detail, dengan konfirmasi.
    await ketuk(tester, find.text('Bayar biaya operasional'));
    await ketuk(tester, find.text('Hapus'));
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus').last); // tombol di dialog
    await tester.pumpAndSettle();
    expect(find.text('Bayar biaya operasional'), findsNothing);
    expect(find.byType(ItemCatatan), findsOneWidget);

    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    await cekKartu(tester, 'Uang masuk', '+Rp700.000');
    await cekKartu(tester, 'Uang keluar', 'Rp0');
    await cekKartu(tester, 'Untung bulan ini', 'Rp700.000');
    expect((await repo.transactions()).single.amount, 700000);
    expect(tester.takeException(), isNull);
  });

  for (final skala in skalaUji) {
    testWidgets('Beranda dengan 5 catatan terakhir, 360dp huruf ${skala}x', (tester) async {
      final repo = await pasangAplikasi(tester, skala: skala);
      final r0 = await muatRingkasanBeranda(repo, hariIni: hariIni, namaUsaha: 'x');
      expect(r0.terakhir, isEmpty);
      for (var i = 1; i <= 7; i++) {
        await catat(tester, 'Masukkan uang pribadi ke usaha (modal)', nominal: i * 1000);
      }
      // Hanya 5 terbaru: modal ke-7 s.d. ke-3 tampil, ke-1 dan ke-2 tidak.
      final teks = await kumpulkanTeks(tester, find.byType(ItemCatatan));
      expect(teks.where((t) => t.startsWith('+Rp')).toSet(),
          {'+Rp7.000', '+Rp6.000', '+Rp5.000', '+Rp4.000', '+Rp3.000'});
      await gulirKe(tester, find.text('Lihat semua catatan'));
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      await ketuk(tester, find.text('Lihat semua catatan'));
      expect(find.byType(ItemCatatan), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
