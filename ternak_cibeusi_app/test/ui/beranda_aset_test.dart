// Bagian 3: ringkasan Aset & stok di Beranda pada 360dp, huruf 1,0x dan 2,0x.
// Angka yang tampil = DataAset dari repository yang sama (satu sumber kebenaran).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/aset_data.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import 'aset_uji.dart';
import 'ui_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'owner_name': 'Peternakan Ayam Cibeusi Makmur Sejahtera'}));

  Future<void> pasang(WidgetTester tester, double skala, {bool isi = true}) async {
    final repo = isi ? await repoAsetUji() : await repoUji();
    aturLayar(tester, skala);
    await tester.pumpWidget(MaterialApp(
      theme: temaSikaya(),
      home: HalamanUtama(repo: repo, hariIni: hariAset),
    ));
    await tester.pumpAndSettle();
  }

  for (final skala in skalaUji) {
    testWidgets('Beranda: Aset & stok 360dp huruf ${skala}x, angka = DataAset', (tester) async {
      await pasang(tester, skala);
      final d = await tester.runAsync(() async => muatDataAset(await repoAsetUji(), hariIni: hariAset));
      expect(d!.nilaiBukuAsetTetap, 13200000);
      await semuaTerlihat(tester, [
        'Aset & stok',
        'Kandang & peralatan', rupiah(d.nilaiBukuAsetTetap),
        'Nilai stok', rupiah(d.nilaiPersediaan),
        'Jumlah ternak', '${d.jumlahTernak} ekor',
        'Stok menipis',
      ]);
      expect(find.textContaining('Pakan: sisa 300 kg, cukup ±5 hari'), findsOneWidget);
      // Kartu memuat angka yang sama dengan DataAset (tidak dihitung ulang di layar).
      final kartu = tester.widget<KartuAngka>(find.byWidgetPredicate((w) => w is KartuAngka && w.judul == 'Nilai stok'));
      expect(kartu.nilai, rupiah(d.nilaiPersediaan));
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Beranda tanpa aset/stok: keadaan kosong yang ramah, huruf 2,0x', (tester) async {
    await pasang(tester, 2.0, isi: false);
    await semuaTerlihat(tester, ['Belum ada aset atau stok']);
    expect(find.text('Jumlah ternak'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
