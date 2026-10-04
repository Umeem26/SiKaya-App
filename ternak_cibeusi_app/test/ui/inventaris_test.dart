// S4: Inventaris (daftar, detail, form) pada 360dp, huruf 1,0x dan 2,0x, dan
// alur tambah -> ubah -> hapus sampai angka di daftar benar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/asset_model.dart';
import 'package:ternak_cibeusi_app/detail_asset_page.dart';
import 'package:ternak_cibeusi_app/form_asset_page.dart';
import 'package:ternak_cibeusi_app/inventaris_data.dart';
import 'package:ternak_cibeusi_app/list_asset_page.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';

import 'ui_helpers.dart';

final hariIni = DateTime(2026, 10, 4);

Future<SumberInventaris> sumberUji({bool isi = true}) async {
  final db = await dbUji();
  final s = SumberInventaris(() async => db);
  if (isi) {
    for (final a in [
      AssetModel(nama: 'Ayam Broiler', kategori: 'Ternak', jumlah: 1200, satuan: 'Ekor', deskripsi: '',
          imagePath: '', date: '2026-10-01', kondisi: 'Baik'),
      AssetModel(nama: 'Kambing Etawa Peranakan Unggul Sekali', kategori: 'Ternak', jumlah: 3, satuan: 'Ekor',
          deskripsi: 'Dari Pak Ujang', imagePath: '/tidak/ada.jpg', date: '2026-09-01', kondisi: 'Perlu Perbaikan'),
      AssetModel(nama: 'Pakan Starter', kategori: 'Operasional Habis Pakai', jumlah: 25, satuan: 'Karung',
          deskripsi: '', imagePath: '', date: '2026-10-02', kondisi: 'Baik'),
      AssetModel(nama: 'Lahan', kategori: 'Aset Tetap', jumlah: 2, satuan: 'tumbak', deskripsi: '',
          imagePath: '', date: '2026-01-01', kondisi: 'Baik', statusKepemilikan: 'Hak Milik dan Sewa',
          fungsiLahan: 'Peternakan, Pertanian'),
    ]) {
      await s.tambah(a);
    }
  }
  return s;
}

Future<void> isiJumlah(WidgetTester tester, String n) async {
  final f = find.descendant(of: find.widgetWithText(LabelIsian, 'Jumlah'), matching: find.byType(TextField));
  await gulirKe(tester, f);
  await tester.enterText(f, n);
}

Finder tombolPilihan(String label) =>
    find.descendant(of: find.byType(TombolPilihan), matching: find.text(label));

void main() {
  for (final skala in skalaUji) {
    testWidgets('daftar inventaris 360dp huruf ${skala}x: kelompok, jumlah, kondisi', (tester) async {
      final s = await sumberUji();
      await pasangHalaman(tester, ListAssetPage(sumber: s), skala: skala);
      await semuaTerlihat(tester, [
        'Ternak (2)', 'Barang habis pakai (1)', 'Kandang, alat & lahan (1)',
        'Ayam Broiler', '1200 Ekor', 'Kondisi: Baik',
        'Kambing Etawa Peranakan Unggul Sekali', '3 Ekor', 'Kondisi: Perlu Perbaikan',
      ]);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      await ketuk(tester, tombolPilihan('Kandang, alat & lahan (1)'));
      await semuaTerlihat(tester, ['Lahan', '2 tumbak']);
      await ketuk(tester, find.text('Lahan'));
      expect(find.byType(DetailAssetPage), findsOneWidget);
      await semuaTerlihat(tester, ['Kandang, alat & lahan', 'Hak Milik dan Sewa', 'Peternakan, Pertanian', 'Ubah', 'Hapus']);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('form inventaris 360dp huruf ${skala}x: semua kelompok, label utuh', (tester) async {
      final s = await sumberUji(isi: false);
      await pasangDitumpuk(tester, FormAssetPage(sumber: s, hariIni: hariIni), skala: skala);
      for (final k in kelompokInventaris) {
        await ketuk(tester, find.text(k.label));
        await semuaTerlihat(tester, [
          'Kelompok', k.keterangan, 'Jenis', ...k.jenis, jenisLainnya, 'Jumlah', 'Satuan',
          ...satuanInventaris, 'Kondisi', ...kondisiInventaris,
          if (k.nilai == 'Aset Tetap') ...[
            'Status kepemilikan (boleh kosong)', ...kepemilikanInventaris,
            'Fungsi lahan (boleh pilih lebih dari satu)', ...fungsiLahanInventaris,
          ],
          'Keterangan (boleh kosong)', 'Foto (boleh kosong)', 'Ambil foto', 'Pilih dari galeri',
        ]);
        cekTinggiKontrol(tester);
        if (skala == 2.0) await cekAreaSentuh(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('alur: tambah -> ubah jumlah & kondisi -> hapus', (tester) async {
    final s = await sumberUji(isi: false);
    await pasangHalaman(tester, ListAssetPage(sumber: s), skala: 1.0);
    await semuaTerlihat(tester, ['Belum ada barang di kelompok ini. Tekan "Tambah barang" di bawah.']);

    // Simpan kosong: jenis dan jumlah wajib.
    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await semuaTerlihat(tester, ['2 isian perlu diperbaiki', 'Pilih jenisnya', 'Jumlah wajib diisi dengan angka']);

    await ketuk(tester, tombolPilihan('Ayam Broiler'));
    await isiJumlah(tester, '500');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await semuaTerlihat(tester, ['Ternak (1)', 'Ayam Broiler', '500 Ekor', 'Kondisi: Baik']);
    final simpan = (await s.semua()).single;
    expect((simpan.nama, simpan.kategori, simpan.jumlah, simpan.satuan, simpan.date),
        ('Ayam Broiler', 'Ternak', 500, 'Ekor', isoTanggal(DateTime.now())));

    await ketuk(tester, find.text('Ayam Broiler'));
    await ketuk(tester, find.text('Ubah'));
    await isiJumlah(tester, '450');
    await ketuk(tester, tombolPilihan('Rusak Ringan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailAssetPage), findsOneWidget);
    await semuaTerlihat(tester, ['450 Ekor', 'Rusak Ringan']);
    expect((await s.semua()).single.date, simpan.date, reason: 'tanggal dicatat tidak berubah saat diubah');

    await ketuk(tester, find.text('Hapus'));
    expect(find.text('Hapus barang ini?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListAssetPage), findsOneWidget);
    await semuaTerlihat(tester, ['Ternak (0)']);
    expect(await s.semua(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data lama dengan nama bebas: ubah memilih "Lainnya" dan mengisi namanya', (tester) async {
    final s = await sumberUji();
    final kambing = (await s.semua()).firstWhere((a) => a.nama.startsWith('Kambing'));
    await pasangDitumpuk(tester, FormAssetPage(asset: kambing, sumber: s), skala: 1.0);
    await gulirKe(tester, find.text('Nama barang'));
    expect(find.text('Kambing Etawa Peranakan Unggul Sekali'), findsOneWidget);
    final lainnya = find.ancestor(of: tombolPilihan(jenisLainnya), matching: find.byType(TombolPilihan));
    expect(tester.widget<TombolPilihan>(lainnya).terpilih, isTrue);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final a = (await s.semua()).firstWhere((a) => a.id == kambing.id);
    expect((a.nama, a.jumlah, a.kondisi, a.deskripsi, a.imagePath),
        (kambing.nama, 3, 'Perlu Perbaikan', 'Dari Pak Ujang', '/tidak/ada.jpg'));
  });
}
