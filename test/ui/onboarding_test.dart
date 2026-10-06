// S4: onboarding pada 360dp, huruf 1,0x dan 2,0x: pengenalan 3 halaman (bisa
// digeser, "Lewati", titik halaman, "Lanjut"/"Mulai", hanya sekali), lalu dua
// langkah (nama usaha, ajakan cadangan berkala); nama tersimpan sesudah langkah cadangan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/onboarding_page.dart';
import 'package:ternak_cibeusi_app/ui/ilustrasi.dart';

import 'ui_helpers.dart';

Future<bool?> introDilihat() async => (await SharedPreferences.getInstance()).getBool(kunciIntroDilihat);

/// Halaman pengenalan yang sedang tampil (0..2), dari PageView.
int halamanAktif(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

void main() {
  for (final skala in skalaUji) {
    testWidgets('pengenalan 360dp huruf ${skala}x: 3 halaman utuh, titik, Lanjut, geser, Mulai', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pasangHalaman(
          tester, OnboardingPage(sesudahnya: (_) => const Scaffold(body: Text('Halaman utama'))),
          skala: skala);
      final h = tester.ensureSemantics();
      for (var i = 0; i < halamanIntro.length; i++) {
        expect(halamanAktif(tester), i);
        final hal = halamanIntro[i];
        // Isi halaman boleh digulir (huruf besar); judul, kalimat, ilustrasi tampil utuh.
        await semuaTerlihat(tester, [hal.judul, hal.isi]);
        expect(find.byType(Ilustrasi), findsOneWidget);
        expect(find.bySemanticsLabel('Halaman ${i + 1} dari 3'), findsOneWidget);
        final terakhir = i == halamanIntro.length - 1;
        expect(find.text('Lewati'), terakhir ? findsNothing : findsOneWidget);
        final tombol = find.widgetWithText(FilledButton, terakhir ? 'Mulai' : 'Lanjut');
        expect(tombol, findsOneWidget);
        expect(tester.getSize(tombol).height, greaterThanOrEqualTo(56));
        dalamLebar(tester, tombol);
        cekTinggiKontrol(tester);
        await cekAreaSentuh(tester);
        expect(tester.takeException(), isNull, reason: 'halaman ${i + 1}');
        if (i == 0) {
          await tester.tap(tombol); // "Lanjut"
        } else if (!terakhir) {
          await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000); // geser ke kiri
        }
        await tester.pumpAndSettle();
      }
      h.dispose();
      expect(await introDilihat(), isNull, reason: 'belum selesai sebelum "Mulai"');
      await tester.tap(find.widgetWithText(FilledButton, 'Mulai'));
      await tester.pumpAndSettle();
      expect(find.text('Langkah 1 dari 2'), findsOneWidget);
      expect(await introDilihat(), isTrue);
    });
  }

  testWidgets('geser ke kanan kembali ke halaman sebelumnya', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pasangHalaman(tester, const OnboardingPage(), skala: 1.0);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(halamanAktif(tester), 1);
    expect(find.text(halamanIntro[1].judul), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(halamanAktif(tester), 0);
  });

  testWidgets('"Lewati" di halaman pertama langsung ke langkah nama dan tercatat sudah dilihat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pasangHalaman(tester, const OnboardingPage(), skala: 2.0);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Langkah 1 dari 2'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(await introDilihat(), isTrue);
  });

  testWidgets('hanya tampil sekali: sudah dilihat -> langsung langkah nama', (tester) async {
    SharedPreferences.setMockInitialValues({kunciIntroDilihat: true});
    await pasangHalaman(tester, const OnboardingPage(), skala: 1.0);
    expect(find.text('Langkah 1 dari 2'), findsOneWidget);
    for (final hal in halamanIntro) {
      expect(find.text(hal.judul), findsNothing);
    }
  });

  testWidgets('tombol kembali HP: langkah nama -> halaman pengenalan terakhir -> sebelumnya', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pasangHalaman(tester, const OnboardingPage(), skala: 1.0);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(halamanIntro.last.judul), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(halamanIntro[1].judul), findsOneWidget);
  });

  for (final skala in skalaUji) {
    testWidgets('langkah penyiapan 360dp huruf ${skala}x: nama -> cadangan berkala -> mulai', (tester) async {
      SharedPreferences.setMockInitialValues({kunciIntroDilihat: true});
      await pasangHalaman(
          tester, OnboardingPage(sesudahnya: (_) => const Scaffold(body: Text('Halaman utama'))),
          skala: skala);

      await semuaTerlihat(tester, ['Langkah 1 dari 2', 'Halo, Juragan!', 'Nama peternakan / pemilik', 'Lanjut']);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);

      // Nama kosong ditolak.
      await ketuk(tester, find.text('Lanjut'));
      await semuaTerlihat(tester, ['Nama tidak boleh kosong ya']);

      await tester.enterText(find.byType(TextFormField), 'Ternak Cibeusi Makmur');
      await ketuk(tester, find.text('Lanjut'));
      await semuaTerlihat(tester, [
        'Langkah 2 dari 2',
        'Simpan cadangan secara berkala',
        'Seminggu sekali:',
        'Buka menu Lainnya (pojok kanan bawah).',
        'Tekan tombol "Ekspor cadangan".',
        'Simpan filenya di Google Drive, atau kirim ke WhatsApp Anda sendiri.',
        'Menu Lainnya akan mengingatkan bila sudah 7 hari belum membuat cadangan.',
        'Mengerti, mulai mencatat',
        'Kembali',
      ]);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      // Belum tersimpan sebelum ajakan cadangan dikonfirmasi.
      expect((await SharedPreferences.getInstance()).getString('owner_name'), isNull);

      await ketuk(tester, find.text('Mengerti, mulai mencatat'));
      expect(find.text('Halaman utama'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('owner_name'), 'Ternak Cibeusi Makmur');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Kembali" dari langkah cadangan ke langkah nama, isian tetap', (tester) async {
    SharedPreferences.setMockInitialValues({kunciIntroDilihat: true});
    await pasangHalaman(tester, const OnboardingPage(), skala: 1.0);
    await tester.enterText(find.byType(TextFormField), 'Cibeusi');
    await ketuk(tester, find.text('Lanjut'));
    await ketuk(tester, find.text('Kembali'));
    expect(find.text('Langkah 1 dari 2'), findsOneWidget);
    expect(find.text('Cibeusi'), findsOneWidget);
  });
}
