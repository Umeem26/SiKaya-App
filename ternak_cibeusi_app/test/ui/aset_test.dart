// Bagian 4: tab Aset (daftar aset tetap, stok, inventaris) dan detail aset
// (riwayat penyusutan dari mesin) pada 360dp, huruf 1,0x dan 2,0x.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/aset_data.dart';
import 'package:ternak_cibeusi_app/aset_page.dart';
import 'package:ternak_cibeusi_app/foto_aset.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/inventaris_data.dart';
import 'package:ternak_cibeusi_app/list_asset_page.dart';

import 'aset_uji.dart';
import 'ui_helpers.dart';

void main() {
  for (final skala in skalaUji) {
    testWidgets('tab Aset 360dp huruf ${skala}x: perolehan, nilai buku, sisa umur, stok', (tester) async {
      final repo = await repoAsetUji();
      await pasangHalaman(tester, AsetPage(repo: repo, hariIni: hariAset, foto: SumberFotoAset.kosong), skala: skala);
      await semuaTerlihat(tester, [
        'Nilai aset & stok', 'Rp15.510.000', // 13.200.000 nilai buku + 2.310.000 stok
        'Kandang, alat & lahan',
        'Kandang panggung bambu', 'Sisa umur 52 bulan', 'Nilai perolehan', 'Rp6.000.000', 'Nilai buku', 'Rp5.200.000',
        'Sudah disusutkan 13% dari 60 bulan',
        'Lahan belakang rumah', 'Tanah, tidak disusutkan', 'Rp8.000.000',
        'Stok pakan, obat & ternak',
        'Pakan', '300 kg', 'Cukup ±5 hari', 'Rp2.100.000',
        'Obat & vitamin', '0 dosis',
        'Ternak / bibit', '30 ekor', 'Rp210.000',
        'Inventaris barang', 'Daftar inventaris',
      ]);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);

      // Detail: riwayat penyusutan dari jadwal mesin, terbaru di atas.
      await ketuk(tester, find.text('Kandang panggung bambu'));
      expect(find.byType(DetailAsetTetapPage), findsOneWidget);
      // Tanpa foto: tidak ada kotak besar; baris ringkas "Tambah foto" di bawah informasi utama.
      expect(find.text('Belum ada foto'), findsNothing);
      expect(find.byType(Image), findsNothing);
      await semuaTerlihat(tester, ['Nilai buku', 'Tambah foto']);
      expect(tester.getRect(find.text('Tambah foto')).top,
          greaterThan(tester.getRect(find.text('Nilai buku').last).bottom));
      expect(tester.getRect(find.text('Tambah foto')).top,
          lessThan(tester.getRect(find.text('Riwayat penyusutan')).top));
      await ketuk(tester, find.text('Tambah foto'));
      await semuaTerlihat(tester, ['Ambil foto', 'Pilih dari galeri']);
      cekTinggiKontrol(tester);
      await tester.tapAt(const Offset(lebarLayar / 2, 20)); // tutup lembar bawah
      await tester.pumpAndSettle();
      expect(find.text('Ambil foto'), findsNothing);
      await semuaTerlihat(tester, [
        'Akumulasi penyusutan', '−Rp800.000', 'Umur manfaat', '60 bulan', 'Sisa umur', '52 bulan',
        'Susut per bulan', 'Rp100.000',
        'Riwayat penyusutan', 'Okt 2026', 'Mar 2026', 'Rp5.900.000', 'Lihat catatan pembelian',
      ]);
      expect(find.text('Susut −Rp100.000'), findsWidgets);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detail aset dengan foto: foto di atas, tombol ganti foto, tanpa baris "Tambah foto"', (tester) async {
    final repo = await repoAsetUji();
    final dir = Directory.systemTemp.createTempSync('sikaya_foto');
    addTearDown(() => dir.deleteSync(recursive: true));
    final foto = SumberFotoAset(() async => dir);
    final data = await muatDataAset(repo, hariIni: hariAset);
    final kandang = data.asetTetap.firstWhere((a) => a.nama == 'Kandang panggung bambu');
    // PNG 1x1 piksel.
    final png = File('${dir.path}/sumber.png')..writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));
    await tester.runAsync(() => foto.simpan(kandang.id, kandang.idBeli, png.path));
    await pasangDitumpuk(tester, DetailAsetTetapPage(aset: kandang, repo: repo, foto: foto), skala: 1.0);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto Kandang panggung bambu'), findsOneWidget);
    expect(find.text('Tambah foto'), findsNothing);
    await semuaTerlihat(tester, ['Ambil foto', 'Pilih dari galeri', 'Nilai buku']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tambah aset langsung membuka form beli aset tetap; inventaris tetap bisa dibuka', (tester) async {
    final repo = await repoAsetUji();
    final db = await dbUji();
    await pasangHalaman(
        tester,
        AsetPage(
            repo: repo, hariIni: hariAset, foto: SumberFotoAset.kosong, inventaris: SumberInventaris(() async => db)),
        skala: 1.0);
    await tester.tap(find.text('Tambah aset'));
    await tester.pumpAndSettle();
    expect(find.byType(FormFinancePage), findsOneWidget);
    expect(find.text('Beli kandang/peralatan/kendaraan/tanah'), findsOneWidget);
    expect(find.text('Ganti pilihan'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AsetPage), findsOneWidget);

    await ketuk(tester, find.text('Daftar inventaris'));
    expect(find.byType(ListAssetPage), findsOneWidget);
  });

  testWidgets('tab Aset kosong, huruf 2,0x: keadaan kosong yang ramah', (tester) async {
    await pasangHalaman(tester, AsetPage(repo: await repoUji(), hariIni: hariAset, foto: SumberFotoAset.kosong));
    await semuaTerlihat(tester, ['Belum ada aset tetap', 'Belum ada stok', 'Rp0']);
    expect(tester.takeException(), isNull);
  });
}
