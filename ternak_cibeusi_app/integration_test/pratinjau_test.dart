// Pratinjau tampilan: isi data demo FIKTIF (data_demo.dart) lalu buka setiap layar
// utama dan ambil foto (loop kualitas UI, docs/UI-REVIEW.md). Tanpa
// --dart-define=SIKAYA_FOTO=true, foto dilewati dan tes ini hanya memastikan semua
// layar terbuka tanpa error.
//
// Foto: bash tool/tangkap_layar.sh emulator-5554 integration_test/pratinjau_test.dart <folder>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/aset_page.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/main.dart';

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

    await tester.pumpWidget(MyApp(home: HalamanUtama(hariIni: hariIni, bagikanPdf: (_, _) async {})));
    await tenang(tester);
    await tungguMuat(tester);

    Future<void> semua(String akhiran) async {
      await keTab(tester, 'Beranda');
      await foto(tester, 'beranda$akhiran');
      await gulirKe(tester, find.text('Aset & stok'));
      await foto(tester, 'beranda-aset$akhiran');
      await keAtas(tester);

      await keTab(tester, 'Catat');
      await foto(tester, 'catatan$akhiran');
      await tester.tap(find.text('Apa yang terjadi?').last);
      await tenang(tester);
      await foto(tester, 'apa-yang-terjadi$akhiran');
      await ketuk(tester, find.text('Jual, dibayar tunai'));
      await foto(tester, 'form-jual$akhiran');
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
      await tester.tap(find.text('Lihat laporan resmi'));
      await tenang(tester);
      await tungguMuat(tester);
      await foto(tester, 'laporan-posisi-keuangan$akhiran');
      await ketuk(tester, find.text('Laba Rugi'));
      await foto(tester, 'laporan-laba-rugi$akhiran');
      await ketuk(tester, find.text('CaLK'));
      await foto(tester, 'calk$akhiran');
      await tester.pageBack();
      await tenang(tester);

      await keTab(tester, 'Lainnya');
      await foto(tester, 'lainnya$akhiran');
    }

    await semua('');
    await hurufSistem(tester, '2.0');
    await semua('-huruf-besar');
    await hurufSistem(tester, '1.0');
    expect(tester.takeException(), isNull);
  });
}
