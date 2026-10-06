// Pratinjau tampilan: isi data demo FIKTIF (data_demo.dart) lalu buka setiap layar
// utama dan ambil foto (loop kualitas UI, docs/UI-REVIEW.md). Tanpa
// --dart-define=SIKAYA_FOTO=true, foto dilewati dan tes ini hanya memastikan semua
// layar terbuka tanpa error.
//
// Foto: bash tool/tangkap_layar.sh emulator-5554 integration_test/pratinjau_test.dart <folder>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/aset_page.dart';
import 'package:ternak_cibeusi_app/asset_model.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/inventaris_data.dart';
import 'package:ternak_cibeusi_app/main.dart';
import 'package:ternak_cibeusi_app/onboarding_page.dart';

import 'alat.dart';
import 'data_demo.dart';

final hariIni = DateTime(2026, 10, 4, 9);
const namaUsaha = 'Peternakan Contoh Sukamaju';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pratinjau semua layar utama dengan data demo', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('owner_name', namaUsaha);
    await prefs.setString('cadangan_terakhir', DateTime(2026, 10, 1).toIso8601String());
    await DatabaseHelper.instance.resetDatabase();
    await isiDataDemo(AccountingRepository.instance);
    // September ditutup buku: lencana "Ditutup" di Catatan, Laporan, dan Lainnya.
    await AccountingRepository.instance.closeBook(DateTime(2026, 9, 30), today: hariIni);
    for (final a in [
      AssetModel(nama: 'Ayam broiler', kategori: 'Ternak', jumlah: 30, satuan: 'Ekor', deskripsi: '',
          imagePath: '', date: '2026-10-02', kondisi: 'Baik'),
      AssetModel(nama: 'Pakan finisher', kategori: 'Operasional Habis Pakai', jumlah: 12, satuan: 'Karung',
          deskripsi: '', imagePath: '', date: '2026-10-03', kondisi: 'Baik'),
      AssetModel(nama: 'Tempat minum otomatis', kategori: 'Aset Tetap', jumlah: 8, satuan: 'Unit', deskripsi: '',
          imagePath: '', date: '2026-03-05', kondisi: 'Perlu Perbaikan'),
    ]) {
      await SumberInventaris.instance.tambah(a);
    }

    Future<void> utama() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MyApp(home: HalamanUtama(hariIni: hariIni, bagikanPdf: (_, _) async {})));
      await tenang(tester);
      await tungguMuat(tester);
    }

    /// Pengenalan 3 halaman dan langkah nama (aplikasi lalu kembali ke HalamanUtama).
    Future<void> pengenalan(String akhiran) async {
      await prefs.remove(kunciIntroDilihat);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MyApp(home: OnboardingPage(sesudahnya: (_) => const SizedBox())));
      await tenang(tester);
      for (var i = 0; i < halamanIntro.length; i++) {
        await tunggu(tester, find.text(halamanIntro[i].judul));
        await foto(tester, 'onboarding-${i + 1}$akhiran');
        await tester.tap(find.text(i == halamanIntro.length - 1 ? 'Mulai' : 'Lanjut'));
        await tenang(tester);
      }
      await foto(tester, 'onboarding-nama$akhiran');
      await utama();
    }

    Future<void> semua(String akhiran) async {
      await pengenalan(akhiran);
      await keTab(tester, 'Beranda');
      await foto(tester, 'beranda$akhiran');
      await gulirKe(tester, find.text('Aset & stok'));
      await foto(tester, 'beranda-aset$akhiran');
      await keAtas(tester);

      await keTab(tester, 'Catat');
      await foto(tester, 'catatan$akhiran');
      await gulirKe(tester, find.text('September 2026'));
      await foto(tester, 'catatan-ditutup$akhiran');
      await keAtas(tester);
      await tester.tap(find.text('Apa yang terjadi?').last);
      await tenang(tester);
      await foto(tester, 'apa-yang-terjadi$akhiran');
      await gulirKe(tester, find.text('Dicatat otomatis'));
      await foto(tester, 'dicatat-otomatis-terlipat$akhiran');
      await ketuk(tester, find.text('Dicatat otomatis'));
      await gulirKe(tester, find.text(txFormSpecs[TxType.tutupBuku]!.label));
      await foto(tester, 'dicatat-otomatis$akhiran');
      await ketuk(tester, find.text(txFormSpecs[TxType.penyusutan]!.label));
      await foto(tester, 'lembar-otomatis$akhiran');
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tenang(tester);
      await ketuk(tester, find.text('Jual, dibayar tunai'));
      await foto(tester, 'form-jual$akhiran');
      await tester.pageBack(); // ke pilihan
      await tenang(tester);
      await ketuk(tester, find.text('Beli kandang/peralatan/kendaraan/tanah'));
      await foto(tester, 'form-aset$akhiran');
      await gulirKe(tester, find.text('Catatan tambahan'));
      await foto(tester, 'form-aset-bawah$akhiran');
      await tester.pageBack(); // ke pilihan
      await tenang(tester);
      await tester.pageBack();
      await tenang(tester);

      await keTab(tester, 'Aset');
      await foto(tester, 'aset$akhiran');
      await gulirKe(tester, find.text('Stok pakan, obat & ternak'));
      await foto(tester, 'aset-stok$akhiran');
      await ketuk(tester, find.text('Kandang panggung bambu'));
      expect(find.byType(DetailAsetTetapPage), findsOneWidget);
      await foto(tester, 'detail-aset$akhiran');
      await gulirKe(tester, find.text('Riwayat penyusutan'));
      await foto(tester, 'riwayat-penyusutan$akhiran');
      await tester.pageBack();
      await tenang(tester);

      await keTab(tester, 'Laporan');
      await foto(tester, 'laporan-ringkasan$akhiran');
      await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1000); // geser ke "Bulan lalu"
      await tenang(tester);
      await tungguMuat(tester);
      await foto(tester, 'laporan-bulan-lalu$akhiran');
      await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1000);
      await tenang(tester);
      await tester.tap(find.text('Lihat laporan resmi'));
      await tenang(tester);
      await tungguMuat(tester);
      await foto(tester, 'laporan-posisi-keuangan$akhiran');
      await ketuk(tester, find.text('Laba Rugi'));
      await foto(tester, 'laporan-laba-rugi$akhiran');
      await ketuk(tester, find.text('CaLK'));
      await foto(tester, 'calk$akhiran');
      await ketuk(tester, find.text('Perubahan Ekuitas')); // tab terakhir: bilah tergulir ke ujung
      await foto(tester, 'laporan-tab-terakhir$akhiran');
      await tester.pageBack();
      await tenang(tester);

      await keTab(tester, 'Lainnya');
      await foto(tester, 'lainnya$akhiran');
      await ketuk(tester, find.text('Daftar inventaris'));
      await tungguMuat(tester);
      await foto(tester, 'inventaris$akhiran');
      await tester.pageBack();
      await tenang(tester);
    }

    await utama();
    await semua('');
    await hurufSistem(tester, '2.0');
    await semua('-huruf-besar');
    await hurufSistem(tester, '1.0');
    expect(tester.takeException(), isNull);
  });
}
