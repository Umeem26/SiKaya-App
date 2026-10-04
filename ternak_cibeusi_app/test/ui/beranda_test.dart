// Tes 2-3 (S1): Beranda dan navigasi di layar 360dp dengan huruf 2,0x tanpa
// overflow, semua label terlihat; tombol "Apa yang terjadi?" membuka alur catat.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/beranda_page.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/lainnya_page.dart';
import 'package:ternak_cibeusi_app/list_finance_page.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

const lebar = 360.0, tinggi = 740.0;

/// Kasus terberat: nama panjang, angka besar, rugi, dua peringatan.
final contoh = RingkasanBeranda(
  namaUsaha: 'Peternakan Ayam Pedaging Cibeusi Makmur Sejahtera',
  dari: DateTime(2026, 10, 1),
  sampai: DateTime(2026, 10, 31),
  uangMasuk: 123456789000,
  uangKeluar: 98765432100,
  kasSekarang: 1234567890123,
  labaBersih: -12345678900,
  perluDitinjau: const ReviewWarning(12, 4500000),
  seimbang: false,
);

void main() {
  late int dimuat;

  Future<void> pasang(WidgetTester tester, {double skala = 2.0}) async {
    tester.view.physicalSize = const Size(lebar, tinggi);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = skala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    dimuat = 0;
    await tester.pumpWidget(MaterialApp(
      theme: temaSikaya(),
      home: HalamanUtama(muatBeranda: () async {
        dimuat++;
        return contoh;
      }),
    ));
    await tester.pumpAndSettle();
  }

  Finder tombolCatat() => find.ancestor(
      of: find.text('Apa yang terjadi?'), matching: find.byWidgetPredicate((w) => w is FilledButton));

  /// Teks tampil utuh di layar: di dalam lebar layar, di atas tombol tetap
  /// "Apa yang terjadi?" (bila ada) dan navigasi bawah.
  void terlihat(WidgetTester tester, Finder f, {bool diAtasTombol = true}) {
    expect(f, findsOneWidget);
    final r = tester.getRect(f);
    var batasBawah = tester.getRect(find.byType(NavigasiBawah)).top;
    if (diAtasTombol && tombolCatat().evaluate().isNotEmpty) {
      batasBawah = tester.getRect(tombolCatat()).top;
    }
    expect(r.left, greaterThanOrEqualTo(0), reason: '$f');
    expect(r.right, lessThanOrEqualTo(lebar), reason: '$f');
    expect(r.top, greaterThanOrEqualTo(0), reason: '$f');
    expect(r.bottom, lessThanOrEqualTo(batasBawah + 0.5), reason: '$f');
  }

  Future<void> gulirSampai(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  for (final skala in [1.0, 2.0]) {
    testWidgets('Beranda + navigasi, 360dp, huruf ${skala}x: tanpa overflow, semua label terlihat',
        (tester) async {
      await pasang(tester, skala: skala);
      // Pengaturan huruf HP benar-benar dipakai (tidak dikunci).
      final ctx = tester.element(find.byType(BerandaPage));
      expect(MediaQuery.textScalerOf(ctx).scale(10), 10 * skala);

      // Navigasi bawah: 4 label tampil, di dalam layar, dan tetap terbaca (>= 14dp).
      for (final t in tujuanNavigasi) {
        final f = find.descendant(of: find.byType(NavigasiBawah), matching: find.text(t.label));
        expect(f, findsOneWidget);
        final r = tester.getRect(f);
        expect(r.left >= 0 && r.right <= lebar && r.bottom <= tinggi, isTrue, reason: t.label);
        expect(r.height, greaterThanOrEqualTo(14), reason: '${t.label} terlalu kecil');
        expect(tester.getSize(find.ancestor(of: f, matching: find.byType(InkWell))).height,
            greaterThanOrEqualTo(48), reason: 'area sentuh ${t.label}');
      }

      // Tombol utama tetap terlihat tanpa digulir: area sentuh >= 56dp, ikon + tulisan.
      terlihat(tester, tombolCatat(), diAtasTombol: false);
      terlihat(tester, find.text('Apa yang terjadi?'), diAtasTombol: false);
      expect(tester.getSize(tombolCatat()).height, greaterThanOrEqualTo(56));
      expect(find.descendant(of: tombolCatat(), matching: find.byType(Icon)), findsOneWidget);

      for (final label in [
        contoh.namaUsaha,
        '12 catatan perlu dicek',
        'Lihat catatan',
        'Laporan tidak seimbang',
        'Uang masuk',
        '+Rp123.456.789.000',
        'Uang keluar',
        '−Rp98.765.432.100',
        'Rugi bulan ini',
        'Rp12.345.678.900',
        'Uang kas sekarang',
        'Rp1.234.567.890.123',
      ]) {
        final f = find.text(label);
        await gulirSampai(tester, f);
        terlihat(tester, f);
      }
      // Sesudah digulir sampai bawah, tombol utama masih terlihat.
      terlihat(tester, tombolCatat(), diAtasTombol: false);

      // Tab Lainnya juga tanpa overflow.
      await tester.tap(find.descendant(of: find.byType(NavigasiBawah), matching: find.text('Lainnya')));
      await tester.pumpAndSettle();
      expect(find.byType(LainnyaPage), findsOneWidget);
      for (final label in ['Cadangan & Pengaturan', 'Inventaris']) {
        await gulirSampai(tester, find.text(label));
        terlihat(tester, find.text(label));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Lihat catatan" pindah ke tab Catatan', (tester) async {
    await pasang(tester, skala: 1.0);
    await gulirSampai(tester, find.text('Lihat catatan'));
    expect(tester.widget<NavigasiBawah>(find.byType(NavigasiBawah)).terpilih, 0);
    await tester.tap(find.text('Lihat catatan'));
    // Tab Catatan (layar lama) memuat DB sungguhan yang tidak selesai di tes -> jangan settle.
    await tester.pump();
    expect(tester.widget<NavigasiBawah>(find.byType(NavigasiBawah)).terpilih, 1);
    expect(find.byType(ListFinancePage), findsOneWidget);
  });

  testWidgets('tap "Apa yang terjadi?" membuka alur catat yang ada, kembali = data dimuat ulang',
      (tester) async {
    await pasang(tester);
    expect(dimuat, 1);
    await tester.tap(find.text('Apa yang terjadi?'));
    // Form lama memuat DB (tidak selesai di tes) -> jangan pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FormFinancePage), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Apa yang terjadi?'), findsOneWidget);

    Navigator.of(tester.element(find.byType(FormFinancePage))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FormFinancePage), findsNothing);
    expect(dimuat, 2);
  });
}
