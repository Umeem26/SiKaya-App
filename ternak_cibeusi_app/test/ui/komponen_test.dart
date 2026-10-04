// Komponen bersama pada layar 360dp, huruf 2,0x: tanpa overflow, area sentuh
// >= 48dp, InputRupiah menghasilkan bilangan bulat, dialog hanya true bila aksi ditekan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

void main() {
  Future<void> pasang(WidgetTester tester, Widget isi) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: temaSikaya(), home: Scaffold(body: isi)));
    await tester.pumpAndSettle();
  }

  test('format Rupiah bilangan bulat', () {
    expect(rupiah(12500000), 'Rp12.500.000');
    expect(rupiah(-5000), '−Rp5.000');
    expect(bertanda(5000), '+Rp5.000');
    expect(bertanda(-5000), '−Rp5.000');
    expect(bertanda(0), 'Rp0');
    expect(bacaRupiah('12.500.000'), 12500000);
    expect(bacaRupiah(''), isNull);
  });

  testWidgets('InputRupiah: titik ribuan, nilai int, tanpa overflow', (tester) async {
    int? nilai;
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pasang(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: InputRupiah(label: 'Harga jual seluruhnya', controller: c, onChanged: (v) => nilai = v),
      ),
    );
    await tester.enterText(find.byType(TextField), '1250000');
    await tester.pump();
    expect(c.text, '1.250.000');
    expect(nilai, 1250000);
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanyaKonfirmasi: tombol berlabel >= 48dp, Batal = false, aksi = true', (tester) async {
    late BuildContext ctx;
    await pasang(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    Future<bool> buka() => tanyaKonfirmasi(ctx,
        judul: 'Hapus catatan ini?',
        isi: 'Catatan dan aset tetapnya ikut terhapus dari laporan.',
        aksi: 'Hapus',
        ikonAksi: Icons.delete,
        bahaya: true);

    var hasil = buka();
    await tester.pumpAndSettle();
    for (final label in ['Batal', 'Hapus']) {
      final tombol = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(tester.getSize(tombol).height, greaterThanOrEqualTo(48), reason: label);
      expect(find.descendant(of: tombol, matching: find.byType(Icon)), findsOneWidget, reason: label);
      final r = tester.getRect(tombol);
      expect(r.left >= 0 && r.right <= 360 && r.bottom <= 740, isTrue, reason: '$label di luar layar');
    }
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(await hasil, isFalse);

    hasil = buka();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(await hasil, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KartuAngka dan BannerPeringatan, huruf 2,0x: tanpa overflow', (tester) async {
    await pasang(
      tester,
      ListView(padding: const EdgeInsets.all(16), children: [
        const KartuAngka(judul: 'Untung bulan ini', nilai: 'Rp1.234.567.890', ikon: Icons.trending_up, nada: Nada.sukses, keterangan: 'Penjualan dikurangi biaya.'),
        BannerPeringatan(judul: '3 catatan perlu dicek', isi: 'Belum dihitung.', aksi: 'Lihat catatan', onAksi: () {}),
      ]),
    );
    expect(find.text('Rp1.234.567.890'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
