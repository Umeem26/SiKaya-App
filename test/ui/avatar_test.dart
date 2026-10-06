// Bagian 1 penyesuaian visual: area profil memakai avatar inisial nama usaha
// (ikon orang bila nama kosong), bukan logo aplikasi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/lainnya_page.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';

import 'ui_helpers.dart';

Finder avatar() => find.byType(AvatarProfil);

void main() {
  test('inisial: huruf pertama dua kata pertama, kosong bila nama kosong', () {
    expect(inisialNama('Ternak Cibeusi Makmur'), 'TC');
    expect(inisialNama('cibeusi'), 'C');
    expect(inisialNama('  peternakan   ayam '), 'PA');
    expect(inisialNama('(CV) Sumber Rejeki'), 'CS');
    expect(inisialNama(''), '');
    expect(inisialNama('   '), '');
    expect(inisialNama(null), '');
  });

  for (final skala in skalaUji) {
    testWidgets('Lainnya huruf ${skala}x: profil berisi avatar inisial, tanpa logo', (tester) async {
      SharedPreferences.setMockInitialValues({'owner_name': 'Ternak Cibeusi'});
      final repo = await repoUji();
      await pasangHalaman(tester, LainnyaPage(repo: repo), skala: skala);
      expect(avatar(), findsOneWidget);
      expect(find.descendant(of: avatar(), matching: find.text('TC')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      dalamLebar(tester, avatar());
      dalamLebar(tester, find.text('Ternak Cibeusi'));
      // Avatar hiasan: pembaca layar membaca nama di sampingnya, bukan inisial.
      final h = tester.ensureSemantics();
      expect(find.bySemanticsLabel('TC'), findsNothing);
      h.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nama kosong: avatar berikon orang', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await repoUji();
    await pasangHalaman(tester, LainnyaPage(repo: repo), skala: 1.0);
    expect(find.descendant(of: avatar(), matching: find.byIcon(Icons.person_rounded)), findsOneWidget);
    expect(find.descendant(of: avatar(), matching: find.byType(Text)), findsNothing);
  });

  testWidgets('ubah nama usaha: inisial avatar ikut berubah', (tester) async {
    SharedPreferences.setMockInitialValues({'owner_name': 'Ternak Cibeusi'});
    final repo = await repoUji();
    await pasangHalaman(tester, LainnyaPage(repo: repo), skala: 1.0);
    await ketuk(tester, find.text('Nama usaha'));
    await tester.enterText(find.byType(TextField), 'Sumber Rejeki');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    await gulirKe(tester, avatar());
    expect(find.descendant(of: avatar(), matching: find.text('SR')), findsOneWidget);
  });
}
