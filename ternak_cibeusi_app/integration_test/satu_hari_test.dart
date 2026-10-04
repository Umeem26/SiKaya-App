// Satu hari penggunaan SiKaya di HP (emulator), dari onboarding sampai "Hapus
// semua data". Data FIKTIF: peternakan ayam pedaging contoh, angka realistis,
// skenario campuran E1-E7 (ACCOUNTING-SPEC-SAK-EMKM.md bagian E). Data ini hanya
// ada di integration_test, tidak di build aplikasi.
//
// Jalankan: flutter test integration_test/satu_hari_test.dart -d <emulator>
// Yang memerlukan layar OS (lembar bagikan, pemilih file, kamera, penampil PDF)
// tidak diotomasi: PDF ditulis ke file sementara lewat pengganti `bagikanPdf`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/beranda_page.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/detail_catatan_page.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/laporan_data.dart';
import 'package:ternak_cibeusi_app/main.dart';
import 'package:ternak_cibeusi_app/onboarding_page.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';

import 'alat.dart';

/// Hari simulasi (tetap, agar angka dan periode bisa diulang).
final hariIni = DateTime(2026, 10, 4);
const namaUsaha = 'Peternakan Contoh Sukamaju';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('satu hari: onboarding, catat, laporan, tutup buku, PDF, hapus semua', (tester) async {
    // Mulai bersih: tanpa pengaturan dan tanpa catatan.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DatabaseHelper.instance.resetDatabase();
    final repo = AccountingRepository.instance;
    expect(await repo.transactions(), isEmpty);

    File? pdf;
    Future<void> simpanPdf(Uint8List isi, String nama) async {
      pdf = File('${(await getTemporaryDirectory()).path}/$nama');
      await pdf!.writeAsBytes(isi, flush: true);
    }

    await tester.pumpWidget(MyApp(
      home: OnboardingPage(
        sesudahnya: (_) => HalamanUtama(hariIni: hariIni, bagikanPdf: simpanPdf),
      ),
    ));
    await tenang(tester);

    // --- 1. Onboarding ---
    expect(find.text('Halo, Juragan!'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tenang(tester);
    expect(find.text('Nama tidak boleh kosong ya'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), namaUsaha);
    await tester.tap(find.text('Lanjut'));
    await tenang(tester);
    expect(find.text('Simpan cadangan secara berkala'), findsOneWidget);
    await ketuk(tester, find.text('Mengerti, mulai mencatat'));
    await tunggu(tester, find.byType(HalamanUtama));
    await tungguMuat(tester);
    expect(find.text(namaUsaha), findsOneWidget);
    expect(prefs.getString('owner_name'), namaUsaha);

    // --- 2. Periode lalu (September): modal, pinjaman, kandang, bibit, pakan ---
    await catat(tester, 'Masukkan uang pribadi ke usaha (modal)', // E2
        tanggal: DateTime(2026, 9, 1), nominal: 20000000);
    await catat(tester, 'Terima pinjaman', // E3
        tanggal: DateTime(2026, 9, 1), teks: {'Pemberi pinjaman / catatan (boleh kosong)': 'Koperasi contoh'},
        nominal: 5000000);
    await catat(tester, 'Beli kandang/peralatan/kendaraan/tanah', // E5
        teks: {'Nama aset': 'Kandang panggung bambu', 'Umur manfaat (bulan)': '60'},
        tanggal: DateTime(2026, 9, 2), pilihan: ['Tunai (kas)'], nominal: 6000000);
    await catat(tester, 'Beli pakan/obat/bibit, bayar tunai',
        tanggal: DateTime(2026, 9, 3), pilihan: ['Ternak / bibit (DOC)'],
        teks: {'Jumlah (kg / dosis / ekor)': '1000'}, nominal: 7000000);
    await catat(tester, 'Beli pakan/obat/bibit, utang',
        tanggal: DateTime(2026, 9, 3), pilihan: ['Pakan'], teks: {'Jumlah (kg / dosis / ekor)': '2000'},
        nominal: 14000000);
    await catat(tester, 'Pakai stok / ternak keluar karena dijual', // E1
        tanggal: DateTime(2026, 9, 30), pilihan: ['Pakan'], teks: {'Jumlah (kg / dosis / ekor)': '1500'});

    // --- 3. Hari ini: panen dan jual, biaya, cicilan, prive, retur ---
    await catat(tester, 'Pakai stok / ternak keluar karena dijual',
        pilihan: ['Ternak / bibit (DOC)'], teks: {'Jumlah (kg / dosis / ekor)': '950'});
    await keAtas(tester);
    await cekKartu(tester, 'Uang masuk', 'Rp0');
    await rekam(tester, true); // rekaman: catat penjualan -> Beranda berubah
    await pelan(tester);
    await catat(tester, 'Jual, dibayar tunai',
        nominal: 20000000, fotoPilihan: 'apa-yang-terjadi', fotoForm: 'form-jual');
    await keAtas(tester);
    await cekKartu(tester, 'Uang masuk', '+Rp20.000.000');
    await keAtas(tester);
    await pelan(tester);
    await pelan(tester);
    await rekam(tester, false);
    await catat(tester, 'Jual, belum dibayar (piutang)', // E6
        teks: {'Nama pembeli / catatan (boleh kosong)': 'Bandar contoh'}, nominal: 12000000);
    await catat(tester, 'Terima pembayaran piutang', // E6 (sebagian)
        pilihan: ['Jual, belum dibayar (piutang)'], nominal: 7000000);
    await catat(tester, 'Ternak mati', teks: {'Jumlah ekor mati': '20'});
    await catat(tester, 'Beli pakan/obat/bibit, bayar tunai',
        pilihan: ['Obat & vitamin'], teks: {'Jumlah (kg / dosis / ekor)': '10'}, nominal: 300000);
    await catat(tester, 'Pakai stok / ternak keluar karena dijual',
        pilihan: ['Obat & vitamin'], teks: {'Jumlah (kg / dosis / ekor)': '4'});
    await catat(tester, 'Bayar biaya operasional', pilihan: ['Upah tenaga kerja'], nominal: 1500000);
    await catat(tester, 'Bayar biaya operasional',
        pilihan: ['Listrik & air', 'Utang (bayar nanti)'], nominal: 350000);
    await catat(tester, 'Bayar bunga pinjaman', nominal: 50000);
    await catat(tester, 'Bayar cicilan pokok pinjaman', nominal: 500000); // E3
    await catat(tester, 'Ambil uang usaha untuk keperluan pribadi', nominal: 1000000); // E4
    await catat(tester, 'Retur / batalkan sebagian transaksi',
        pilihan: ['Jual, dibayar tunai'], nominal: 500000);
    expect(await repo.transactions(), hasLength(19)); // 6 September + 13 hari ini

    // --- 4. Beranda = hitungan mesin (dan hitungan tangan untuk saldo) ---
    final okt = await repo.loadReport(asOf: hariIni, from: DateTime(2026, 10, 1));
    final r = okt.report;
    expect(r.balanced, isTrue); // E7: invarian D1
    expect(r.perluDitinjau, isEmpty);
    // Hitung tangan: kas 20jt+5jt-6jt-7jt (Sep) +20jt+7jt-0,3jt-1,5jt-0,05jt-0,5jt-1jt-0,5jt (Okt).
    expect(okt.kas.saldo, 35150000);
    expect(r.kas, 35150000); // D3: kas laporan = buku kas
    expect(r.piutang, 5000000);
    expect(r.utang, 14000000 + 4500000 + 350000);
    expect(r.persediaanTotal, 500 * 7000 + 30 * 7000 + 6 * 30000);
    expect(r.pendapatan, 31500000);
    expect(r.labaBersih, r.pendapatan - r.bebanTotal); // D2

    final b = await muatRingkasanBeranda(repo, hariIni: hariIni, namaUsaha: namaUsaha);
    await keTab(tester, 'Beranda');
    await cekKartu(tester, 'Uang masuk', bertanda(b.uangMasuk));
    await cekKartu(tester, 'Uang keluar', bertanda(-b.uangKeluar));
    await cekKartu(tester, b.labaBersih >= 0 ? 'Untung bulan ini' : 'Rugi bulan ini', rupiah(b.labaBersih.abs()));
    await cekKartu(tester, 'Uang kas sekarang', rupiah(35150000));
    expect(b.labaBersih, r.labaBersih);
    await keAtas(tester);
    await foto(tester, 'beranda');
    await hurufSistem(tester, '2.0');
    await foto(tester, 'beranda-huruf-besar');
    await hurufSistem(tester, '1.0');

    await keTab(tester, 'Catat');
    await gulirKe(tester, find.text('Jual, dibayar tunai'));
    await keAtas(tester);
    await foto(tester, 'catatan');

    // --- 5. Laporan ringkasan dan resmi = hitungan mesin ---
    final d = await muatDataLaporan(repo, dari: DateTime(2026, 10, 1), sampai: hariIni, namaUsaha: namaUsaha);
    await keTab(tester, 'Laporan');
    expect(find.text('1 Oktober 2026 s.d. 4 Oktober 2026'), findsOneWidget);
    await foto(tester, 'laporan-ringkasan');
    await cekKartu(tester, 'Uang masuk', bertanda(d.uangMasuk));
    await cekKartu(tester, 'Uang keluar', bertanda(-d.uangKeluar));
    await cekKartu(tester, d.untungRugi >= 0 ? 'Untung' : 'Rugi', rupiah(d.untungRugi.abs()));
    await cekKartu(tester, 'Uang kas di akhir waktu ini', rupiah(d.kasAkhir));
    await cekKartu(tester, 'Nilai stok', rupiah(d.nilaiStok));
    await cekKartu(tester, 'Nilai kandang & peralatan', rupiah(d.nilaiAsetTetap));
    await cekKartu(tester, 'Utang', rupiah(d.utang));
    await cekKartu(tester, 'Piutang', rupiah(d.piutang));
    expect((d.kasAkhir, d.untungRugi, d.utang), (r.kas, r.labaBersih, r.utang));

    await tester.tap(find.text('Lihat laporan resmi'));
    await tunggu(tester, find.text('Laporan Posisi Keuangan'));
    await foto(tester, 'laporan-posisi-keuangan');
    await cekBaris(tester, 'Kas', angkaResmi(r.kas));
    await cekBaris(tester, 'Piutang usaha', angkaResmi(r.piutang));
    await cekBaris(tester, 'Nilai buku aset tetap', angkaResmi(r.asetTetapNeto));
    await cekBaris(tester, 'JUMLAH ASET', angkaResmi(r.totalAset));
    await cekBaris(tester, 'JUMLAH LIABILITAS DAN EKUITAS', angkaResmi(r.totalAset));
    await keAtas(tester);
    await tester.tap(find.text('Laba Rugi'));
    await tenang(tester);
    await cekBaris(tester, 'Pendapatan penjualan', angkaResmi(31500000));
    await cekBaris(tester, 'Jumlah beban', angkaResmi(r.bebanTotal));
    await cekBaris(tester, 'LABA (RUGI) BERSIH', angkaResmi(d.untungRugi));
    await keAtas(tester);
    await tester.tap(find.text('CaLK'));
    await tenang(tester);
    expect(find.text('Catatan atas Laporan Keuangan'), findsWidgets);
    expect(d.calk, isNotEmpty);
    await gulirKe(tester, find.text(d.calk.first.judul));
    await keAtas(tester);
    await foto(tester, 'calk');
    await tester.pageBack();
    await tenang(tester);

    // --- 6. Tutup buku periode lalu (sampai 30 September) ---
    final asetSebelum = r.totalAset;
    await keTab(tester, 'Lainnya');
    await foto(tester, 'lainnya');
    await ketuk(tester, find.text('Tutup buku'));
    await tester.tap(find.text('Pilih')); // kalender mulai di akhir bulan lalu
    await tunggu(tester, find.text('Ekspor cadangan dulu?'));
    await tester.tap(find.text('Lewati')); // ekspor = lembar bagikan OS, tidak diotomasi
    await tunggu(tester, find.text('Tutup buku sampai 30 September 2026?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Tutup buku'));
    await tunggu(tester, find.text('Tutup buku selesai'));
    await tester.tap(find.text('Mengerti'));
    await tenang(tester);
    expect(await repo.lockedUntil(), DateTime(2026, 9, 30));
    expect((await repo.loadReport(asOf: hariIni)).report.totalAset, asetSebelum); // D5
    expect(await repo.transactions(), hasLength(20)); // + entri tutup buku, tidak ada yang hilang

    // --- 7. Catatan lama terkunci: ubah dan hapus ditolak ---
    await keTab(tester, 'Catat');
    await ketuk(tester, find.text('Masukkan uang pribadi ke usaha (modal)'));
    expect(find.byType(DetailCatatanPage), findsOneWidget);
    await ketuk(tester, find.text('Ubah'));
    await isi(tester, isianRupiah, '25000000');
    await tester.tap(find.text('Simpan perubahan'));
    await tunggu(tester, find.text('Tidak bisa disimpan'));
    expect(find.textContaining('sudah ditutup buku'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tenang(tester);
    await tester.pageBack();
    await tenang(tester);
    await ketuk(tester, find.text('Hapus'));
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus').last); // tombol di dialog
    await tunggu(tester, find.text('Tidak bisa dihapus'));
    await tester.tap(find.text('Mengerti'));
    await tenang(tester);
    await tester.pageBack();
    await tenang(tester);
    final modal = (await repo.transactions()).where((t) => t.date == '2026-09-01' && t.amount == 20000000);
    expect(modal, hasLength(1), reason: 'catatan modal September tidak berubah');
    expect(find.byType(FormFinancePage), findsNothing);

    // --- 8. Ekspor PDF: file terbentuk (lembar bagikan OS tidak dibuka) ---
    await keTab(tester, 'Laporan');
    await tester.tap(find.text('Lihat laporan resmi'));
    await tunggu(tester, find.text('Ekspor PDF'));
    await tester.tap(find.text('Ekspor PDF'));
    await tungguSampai(tester, () => pdf != null || find.text('PDF gagal dibuat').evaluate().isNotEmpty, 'PDF');
    await tunggu(tester, find.text('Ekspor PDF')); // tombol kembali dari "Membuat PDF..."
    expect(find.text('PDF gagal dibuat'), findsNothing);
    expect(pdf, isNotNull);
    expect(pdf!.path, endsWith('laporan_keuangan_2026-10-01_2026-10-04.pdf'));
    final isiPdf = await pdf!.readAsBytes();
    expect(isiPdf.length, greaterThan(2000));
    expect(String.fromCharCodes(isiPdf.take(5)), '%PDF-');
    await tester.pageBack();
    await tenang(tester);

    // --- 9. Hapus semua data -> kembali ke onboarding ---
    await keTab(tester, 'Lainnya');
    await ketuk(tester, find.text('Hapus semua data'));
    expect(find.text('Hapus semua data?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus semuanya'));
    await tunggu(tester, find.text('Halo, Juragan!'));
    expect(find.byType(HalamanUtama), findsNothing);
    expect(await repo.transactions(), isEmpty);
    expect((await SharedPreferences.getInstance()).getString('owner_name'), isNull);
  });
}
