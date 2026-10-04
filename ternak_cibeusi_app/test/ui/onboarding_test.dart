// S4: onboarding dua langkah (nama usaha, ajakan cadangan berkala) pada 360dp,
// huruf 1,0x dan 2,0x; nama tersimpan sesudah langkah cadangan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/onboarding_page.dart';

import 'ui_helpers.dart';

void main() {
  for (final skala in skalaUji) {
    testWidgets('onboarding 360dp huruf ${skala}x: nama -> cadangan berkala -> mulai', (tester) async {
      SharedPreferences.setMockInitialValues({});
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
    SharedPreferences.setMockInitialValues({});
    await pasangHalaman(tester, const OnboardingPage(), skala: 1.0);
    await tester.enterText(find.byType(TextFormField), 'Cibeusi');
    await ketuk(tester, find.text('Lanjut'));
    await ketuk(tester, find.text('Kembali'));
    expect(find.text('Langkah 1 dari 2'), findsOneWidget);
    expect(find.text('Cibeusi'), findsOneWidget);
  });
}
