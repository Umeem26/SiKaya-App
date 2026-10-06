// Bagian 4 penyesuaian visual: bagian setara berupa tab geser (TabGeser +
// TabBarView): geser memindahkan tab, tab terpilih tergulir ke tampilan dan
// terlihat utuh pada huruf 2,0x di 360dp, tepi memudar bila ada tab di luar
// layar, area sentuh >= 48dp, geser tegak tidak memindahkan tab.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/form_asset_page.dart';
import 'package:ternak_cibeusi_app/inventaris_data.dart';
import 'package:ternak_cibeusi_app/laporan_resmi_page.dart';
import 'package:ternak_cibeusi_app/list_asset_page.dart';
import 'package:ternak_cibeusi_app/report_page.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import 'inventaris_test.dart' show sumberUji;
import 'laporan_test.dart' show hariIni, repoLaporan;
import 'ui_helpers.dart';

TabController pengendali(WidgetTester tester) => tester.widget<TabGeser>(find.byType(TabGeser)).controller;

Finder tab(String label) => find.descendant(of: find.byType(TabGeser), matching: find.text(label));

/// Geser isi (TabBarView) ke kiri = tab berikutnya.
Future<void> geserKiri(WidgetTester tester) async {
  await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
}

/// Tab terpilih: pil bercentang, label terlihat utuh di layar.
void cekTerpilihTerlihat(WidgetTester tester, String label) {
  dalamLebar(tester, tab(label));
  final pil = find.ancestor(of: tab(label), matching: find.byType(Row)).first;
  expect(find.descendant(of: pil, matching: find.byIcon(Icons.check_rounded)), findsOneWidget, reason: label);
}

void main() {
  for (final skala in skalaUji) {
    testWidgets('laporan resmi ${skala}x: geser memindahkan tab, tab terpilih terlihat, area sentuh', (tester) async {
      final repo = await repoLaporan();
      await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: skala);
      await tester.tap(find.text('Lihat laporan resmi'));
      await tester.pumpAndSettle();
      expect(find.byType(LaporanResmiPage), findsOneWidget);

      const judul = [
        'Laporan Posisi Keuangan',
        'Laporan Laba Rugi',
        'Catatan atas Laporan Keuangan',
        'Laporan Perubahan Ekuitas',
      ];
      for (var i = 0; i < judulTabResmi.length; i++) {
        expect(pengendali(tester).index, i);
        cekTerpilihTerlihat(tester, judulTabResmi[i]);
        expect(find.text(judul[i]), findsOneWidget, reason: 'isi tab ${judulTabResmi[i]}');
        // Setiap tab yang tergambar: tinggi area ketuk >= 48dp.
        for (final l in judulTabResmi) {
          final ink = find.ancestor(of: tab(l), matching: find.byType(InkWell));
          if (ink.evaluate().isNotEmpty) expect(tester.getSize(ink.first).height, greaterThanOrEqualTo(48));
        }
        await cekAreaSentuh(tester);
        if (i < judulTabResmi.length - 1) await geserKiri(tester);
      }
      // Geser ke kanan kembali ke tab sebelumnya.
      await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(pengendali(tester).index, judulTabResmi.length - 2);
      cekTerpilihTerlihat(tester, judulTabResmi[judulTabResmi.length - 2]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('huruf 2,0x: tepi kanan memudar selama ada tab di luar layar, kiri sesudah digulir', (tester) async {
    final repo = await repoLaporan();
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 2.0);
    TabGeserState state() => tester.state<TabGeserState>(find.byType(TabGeser));
    expect(state().pudar, (kiri: false, kanan: true));
    // Tab terakhir dipilih -> bilah tergulir ke ujung -> hanya kiri yang memudar.
    pengendali(tester).animateTo(3);
    await tester.pumpAndSettle();
    expect(state().pudar, (kiri: true, kanan: false));
    dalamLebar(tester, tab('Pilih tanggal'));
  });

  testWidgets('layar lebar: semua tab muat -> tidak ada tepi yang memudar', (tester) async {
    final s = await sumberUji();
    aturLayar(tester, 1.0);
    tester.view.physicalSize = const Size(1600, 740); // tablet: semua kelompok muat sebaris
    await tester.pumpWidget(MaterialApp(theme: temaSikaya(), home: ListAssetPage(sumber: s)));
    await tester.pumpAndSettle();
    expect(tester.state<TabGeserState>(find.byType(TabGeser)).pudar, (kiri: false, kanan: false));
  });

  testWidgets('ringkasan: geser tegak tidak memindahkan tab; geser bilah tab tidak mengganti pilihan',
      (tester) async {
    final repo = await repoLaporan();
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 2.0);
    await tester.drag(find.byType(TabBarView), const Offset(-20, -400)); // gulir isi ke bawah (agak miring)
    await tester.pumpAndSettle();
    expect(pengendali(tester).index, 0);
    await tester.drag(find.byType(TabBar), const Offset(-200, 0)); // gulir bilah tab saja
    await tester.pumpAndSettle();
    expect(pengendali(tester).index, 0);
    expect(tester.state<TabGeserState>(find.byType(TabGeser)).pudar.kiri, isTrue);
  });

  testWidgets('ringkasan: geser ke "Pilih tanggal" -> ajakan memilih tanggal, tombol bawah "Pilih tanggal"',
      (tester) async {
    final repo = await repoLaporan();
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 1.0);
    for (var i = 0; i < 3; i++) {
      await geserKiri(tester);
    }
    expect(pengendali(tester).index, 3);
    expect(find.text('Pilih tanggal awal dan akhir'), findsOneWidget);
    expect(find.text('Lihat laporan resmi'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Pilih tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih').last); // kalender rentang: awal = bulan ini
    await tester.pumpAndSettle();
    expect(find.text('1 Februari 2026 s.d. 15 Februari 2026'), findsOneWidget);
    expect(find.text('Ubah tanggal'), findsOneWidget);
    expect(find.text('Lihat laporan resmi'), findsOneWidget);
  });

  testWidgets('inventaris 2,0x: geser ke kelompok lain, "Tambah barang" memakai kelompok yang tampil',
      (tester) async {
    final s = await sumberUji();
    await pasangHalaman(tester, ListAssetPage(sumber: s), skala: 2.0);
    await gulirKe(tester, find.text('Ayam Broiler'));
    await geserKiri(tester);
    await geserKiri(tester);
    expect(pengendali(tester).index, 2);
    cekTerpilihTerlihat(tester, 'Kandang, alat & lahan (1)');
    expect(find.text('Ayam Broiler'), findsNothing);
    await gulirKe(tester, find.text('Lahan'));
    cekTinggiKontrol(tester);
    await cekAreaSentuh(tester);
    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();
    expect(tester.widget<FormAssetPage>(find.byType(FormAssetPage)).kelompokAwal, kelompokInventaris[2].nilai);
    expect(tester.takeException(), isNull);
  });
}
