// Alat bantu tes layar (S2-S4): layar 360dp, skala huruf, DB in-memory yang
// bisa dipakai di testWidgets, cek terlihat dan area sentuh >= 48dp.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/database/schema.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

const lebarLayar = 360.0, tinggiLayar = 740.0;
const skalaUji = [1.0, 2.0];

/// Layar HP 360x740dp dengan skala huruf [skala] (setelan font HP).
void aturLayar(WidgetTester tester, double skala) {
  tester.view.physicalSize = const Size(lebarLayar, tinggiLayar);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = skala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> pasangHalaman(WidgetTester tester, Widget halaman, {double skala = 2.0}) async {
  aturLayar(tester, skala);
  await tester.pumpWidget(MaterialApp(theme: temaSikaya(), home: halaman));
  await tester.pumpAndSettle();
}

/// Halaman ditumpuk di atas halaman awal, agar halaman boleh menutup diri (pop).
Future<void> pasangDitumpuk(WidgetTester tester, Widget halaman, {double skala = 2.0}) async {
  aturLayar(tester, skala);
  await tester.pumpWidget(MaterialApp(theme: temaSikaya(), home: const Scaffold(body: Text('Halaman awal'))));
  tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => halaman));
  await tester.pumpAndSettle();
}

/// DB in-memory tanpa isolate: selesai di dalam testWidgets (fake async).
Future<AccountingRepository> repoUji() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: dbVersion,
      onConfigure: configureDb,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
      singleInstance: false,
    ),
  );
  addTearDown(db.close);
  return AccountingRepository(() async => db);
}

/// Daftar gulir vertikal halaman teratas (bukan TabBar/PageView yang horizontal).
Finder daftarUtama() =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Gulir daftar utama halaman teratas sampai [f] (boleh lebih dari satu) terlihat.
Future<void> gulirKe(WidgetTester tester, Finder f, {double langkah = 150}) async {
  if (f.evaluate().isEmpty) {
    final pos = tester.state<ScrollableState>(daftarUtama().first).position;
    pos.jumpTo(0);
    await tester.pump();
    while (f.evaluate().isEmpty && pos.pixels < pos.maxScrollExtent) {
      pos.jumpTo((pos.pixels + langkah).clamp(0, pos.maxScrollExtent));
      await tester.pump();
    }
  }
  expect(f, findsWidgets, reason: 'tidak ditemukan sesudah digulir');
  Scrollable.ensureVisible(f.evaluate().first, alignment: 0.3);
  await tester.pumpAndSettle();
}

/// Semua teks di dalam [dalam] yang pernah tampil saat daftar utama digulir dari
/// atas sampai bawah (daftar dibangun malas, jadi tidak bisa dihitung sekaligus).
Future<Set<String>> kumpulkanTeks(WidgetTester tester, Finder dalam, {double langkah = 100}) async {
  final pos = tester.state<ScrollableState>(daftarUtama().first).position;
  final hasil = <String>{};
  void ambil() {
    for (final e in find.descendant(of: dalam, matching: find.byType(Text)).evaluate()) {
      final d = (e.widget as Text).data;
      if (d != null) hasil.add(d);
    }
  }

  pos.jumpTo(0);
  await tester.pump();
  ambil();
  while (pos.pixels < pos.maxScrollExtent) {
    pos.jumpTo((pos.pixels + langkah).clamp(0, pos.maxScrollExtent));
    await tester.pump();
    ambil();
  }
  return hasil;
}

/// Gulir lalu ketuk [f] (yang pertama bila lebih dari satu).
Future<void> ketuk(WidgetTester tester, Finder f) async {
  await gulirKe(tester, f);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// [f] tampil utuh secara horizontal (tidak terpotong tepi layar) dan, bila
/// teks, tidak dipotong "..." (maxLines).
void dalamLebar(WidgetTester tester, Finder f) {
  expect(f, findsWidgets);
  for (final e in f.evaluate()) {
    final box = e.renderObject! as RenderBox;
    final r = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$f terpotong kiri');
    expect(r.right, lessThanOrEqualTo(lebarLayar + 0.5), reason: '$f terpotong kanan');
    if (box is RenderParagraph) expect(box.didExceedMaxLines, isFalse, reason: '$f terpotong');
  }
}

/// Gulir ke setiap teks, pastikan tampil dalam lebar layar.
Future<void> semuaTerlihat(WidgetTester tester, Iterable<String> teks) async {
  for (final s in teks) {
    final f = find.text(s, findRichText: true);
    await gulirKe(tester, f);
    dalamLebar(tester, f);
  }
}

/// Pedoman Android: setiap target ketuk yang terlihat minimal 48x48dp.
Future<void> cekAreaSentuh(WidgetTester tester) async {
  final h = tester.ensureSemantics();
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  h.dispose();
}

/// Semua tombol/baris ketuk yang tampil di layar: tinggi >= 48dp.
void cekTinggiKontrol(WidgetTester tester) {
  final kontrol = find.byWidgetPredicate((w) =>
      w is ButtonStyleButton || w is InkWell || w is CheckboxListTile || w is TextField);
  for (final e in kontrol.evaluate()) {
    // InkWell di dalam tombol: area sentuhnya = tombol (diberi padding 48dp).
    var dalamTombol = false;
    if (e.widget is InkWell) {
      e.visitAncestorElements((a) {
        dalamTombol = a.widget is ButtonStyleButton;
        return !dalamTombol;
      });
    }
    if (dalamTombol) continue;
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) continue;
    final atas = box.localToGlobal(Offset.zero).dy;
    if (atas < 0 || atas + box.size.height > tinggiLayar) continue; // di luar layar
    expect(box.size.height, greaterThanOrEqualTo(48), reason: '${e.widget.runtimeType} terlalu pendek');
  }
}
