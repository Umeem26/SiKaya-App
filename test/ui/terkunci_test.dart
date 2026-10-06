// Bagian 2 penyesuaian visual: yang terkunci tidak tampak rusak atau mati.
// Catatan otomatis di kelompok "Dicatat otomatis" yang terlipat (ikon info,
// bukan gembok); ketuk = lembar bawah berisi alasan + satu tombol pintas;
// periode yang sudah ditutup buku berlencana "Ditutup" di daftar dan laporan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/detail_catatan_page.dart';
import 'package:ternak_cibeusi_app/foto_aset.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/lainnya_page.dart';
import 'package:ternak_cibeusi_app/laporan_resmi_page.dart';
import 'package:ternak_cibeusi_app/list_finance_page.dart';
import 'package:ternak_cibeusi_app/report_page.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';
import 'package:ternak_cibeusi_app/ui/item_catatan.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import 'ui_helpers.dart';

final hariIni = DateTime(2026, 10, 4);
final penyusutan = txFormSpecs[TxType.penyusutan]!.label;
final tutupBuku = txFormSpecs[TxType.tutupBuku]!.label;

/// September (modal, jual) dan Oktober (jual 1 dan 3 Okt); tutup buku sampai [sampai] bila diisi.
Future<AccountingRepository> repoDitutup({DateTime? sampai}) async {
  SharedPreferences.setMockInitialValues({'owner_name': 'Ternak Cibeusi'});
  final db = await dbUji();
  final repo = AccountingRepository(() async => db, backup: () async => '/data/cadangan_tutupbuku.db');
  for (final t in const [
    TransactionModel(txType: TxType.setorModal, amount: 5000000, date: '2026-09-10'),
    TransactionModel(txType: TxType.penjualanTunai, amount: 800000, date: '2026-09-20'),
    TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-10-01'),
    TransactionModel(txType: TxType.penjualanTunai, amount: 300000, date: '2026-10-03'),
  ]) {
    await repo.insertTransaction(t);
  }
  if (sampai != null) await repo.closeBook(sampai, today: hariIni);
  return repo;
}

Future<void> pasangUtama(WidgetTester tester, AccountingRepository repo, {double skala = 1.0}) async {
  aturLayar(tester, skala);
  await tester.pumpWidget(MaterialApp(
    theme: temaSikaya(),
    home: HalamanUtama(repo: repo, hariIni: hariIni, fotoAset: SumberFotoAset.kosong),
  ));
  await tester.pumpAndSettle();
}

Future<void> keTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigasiBawah), matching: find.text(label)));
  await tester.pumpAndSettle();
}

int tabTerpilih(WidgetTester tester) => tester.widget<NavigasiBawah>(find.byType(NavigasiBawah)).terpilih;

Finder lembar() => find.byType(BottomSheet);

/// Tutup lembar bawah (pada huruf besar lembar menutupi hampir seluruh layar).
Future<void> tutupLembar(WidgetTester tester) async {
  Navigator.pop(tester.element(lembar()));
  await tester.pumpAndSettle();
}

/// Lembar alasan terbuka: judul, tombol pintas >= 48dp dan terlihat utuh.
Future<void> cekLembar(WidgetTester tester, String judul, String aksi) async {
  expect(lembar(), findsOneWidget);
  expect(find.descendant(of: lembar(), matching: find.text(judul)), findsOneWidget);
  final tombol = find.descendant(of: lembar(), matching: find.widgetWithText(FilledButton, aksi));
  expect(tombol, findsOneWidget);
  await tester.ensureVisible(tombol);
  await tester.pumpAndSettle();
  expect(tester.getSize(tombol).height, greaterThanOrEqualTo(48));
  dalamLebar(tester, tombol);
  dalamLebar(tester, find.descendant(of: lembar(), matching: find.text(judul)));
}

void main() {
  for (final skala in skalaUji) {
    testWidgets('"Dicatat otomatis" ${skala}x: terlipat, ikon info, ketuk = lembar alasan', (tester) async {
      await pasangDitumpuk(tester, FormFinancePage(repo: await repoUji(), hariIni: hariIni), skala: skala);
      // Terlipat: kepala berikon info dan kalimat penjelas; isinya belum tampil.
      final kelompok = find.byType(KelompokLipat);
      await gulirKe(tester, kelompok);
      await semuaTerlihat(tester, ['Dicatat otomatis', 'SiKaya mencatat ini sendiri, jadi tidak perlu dipilih.']);
      expect(find.descendant(of: kelompok, matching: find.byIcon(Icons.info_outline_rounded)), findsWidgets);
      expect(find.text(penyusutan), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await ketuk(tester, find.text('Dicatat otomatis'));
      await semuaTerlihat(tester, [penyusutan, tutupBuku, 'Sembunyikan']);
      // Kartu info berbeda gaya dari kartu pilihan: rata (tanpa bayangan), tanpa panah.
      final kartu = find.ancestor(of: find.text(penyusutan), matching: find.byType(KartuPilihan));
      expect(find.descendant(of: kartu, matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing);
      expect(tester.widget<Material>(find.descendant(of: kartu, matching: find.byType(Material)).first).elevation, 0);
      final aktif = find.ancestor(of: find.text('Jual, dibayar tunai'), matching: find.byType(KartuPilihan));
      await gulirKe(tester, aktif);
      expect(tester.widget<Material>(find.descendant(of: aktif, matching: find.byType(Material)).first).elevation,
          greaterThan(0));
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);

      await ketuk(tester, find.text(penyusutan));
      await cekLembar(tester, 'Penyusutan dihitung otomatis', 'Lihat di tab Aset');
      expect(find.byType(FormFinancePage), findsOneWidget, reason: 'tidak memilih jenis');
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tombol pintas lembar alasan: tutup buku -> tab Lainnya, halaman catat ditutup', (tester) async {
    final repo = await repoDitutup();
    await pasangUtama(tester, repo);
    await keTab(tester, 'Catat');
    await tester.tap(find.widgetWithText(FilledButton, 'Apa yang terjadi?'));
    await tester.pumpAndSettle();
    await ketuk(tester, find.text('Dicatat otomatis'));
    await ketuk(tester, find.text(tutupBuku));
    await cekLembar(tester, 'Tutup buku dibuat dari menu Lainnya', 'Buka Tutup buku di Lainnya');
    await tester.tap(find.text('Buka Tutup buku di Lainnya'));
    await tester.pumpAndSettle();
    expect(lembar(), findsNothing);
    expect(find.byType(FormFinancePage), findsNothing);
    expect(tabTerpilih(tester), TabUtama.lainnya);
    expect(find.byType(LainnyaPage), findsOneWidget);
  });

  testWidgets('pilihan yang belum tersedia: kartu info + lembar; pintas piutang membuka form jual kredit',
      (tester) async {
    await pasangDitumpuk(tester, FormFinancePage(repo: await repoUji(), hariIni: hariIni), skala: 1.0);
    for (final s in ['Belum ada catatan yang bisa diretur.', 'Belum ada penjualan yang belum dibayar.']) {
      await semuaTerlihat(tester, [s]);
    }
    expect(find.textContaining('Belum bisa dipilih'), findsNothing);
    await ketuk(tester, find.text(returFormSpec.label));
    await cekLembar(tester, 'Belum ada catatan yang bisa diretur', 'Lihat daftar catatan');
    await tutupLembar(tester);

    await ketuk(tester, find.text(txFormSpecs[TxType.terimaPiutang]!.label));
    await cekLembar(tester, 'Belum ada yang berutang kepada Anda', 'Catat jual belum dibayar');
    await tester.tap(find.text('Catat jual belum dibayar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Catat'), findsOneWidget);
    expect(find.text(txFormSpecs[TxType.penjualanKredit]!.label), findsOneWidget);
  });

  for (final skala in skalaUji) {
    testWidgets('Catatan ${skala}x: bulan yang ditutup berlencana "Ditutup", ketuk = lembar', (tester) async {
      final repo = await repoDitutup(sampai: DateTime(2026, 9, 30));
      await pasangHalaman(tester, ListFinancePage(repo: repo), skala: skala);
      await gulirKe(tester, find.text('September 2026'));
      final lencana = find.byType(LencanaDitutup);
      expect(lencana, findsOneWidget, reason: 'hanya bulan September; Oktober belum ditutup');
      dalamLebar(tester, find.text('Ditutup'));
      expect(tester.getSize(lencana).height, greaterThanOrEqualTo(48));
      await tester.tap(lencana);
      await tester.pumpAndSettle();
      await cekLembar(tester, 'Sudah ditutup buku sampai 30 September 2026', 'Lihat Tutup buku di Lainnya');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Catatan: bulan yang ditutup sebagian -> lencana per catatan', (tester) async {
    final repo = await repoDitutup(sampai: DateTime(2026, 10, 2));
    await pasangHalaman(tester, ListFinancePage(repo: repo), skala: 1.0);
    // Daftar dibangun malas: kumpulkan tanggal catatan berlencana sambil menggulir.
    final ditutup = <String>{}, terbuka = <String>{};
    final pos = tester.state<ScrollableState>(daftarUtama().first).position;
    while (true) {
      for (final w in tester.widgetList<ItemCatatan>(find.byType(ItemCatatan))) {
        (w.ditutup ? ditutup : terbuka).add(w.catatan.date);
      }
      if (pos.pixels >= pos.maxScrollExtent) break;
      pos.jumpTo((pos.pixels + 100).clamp(0, pos.maxScrollExtent));
      await tester.pump();
    }
    // Oktober ditutup sebagian: 1 Okt dan entri tutup buku 2 Okt berlencana, 3 Okt tidak.
    // September ditutup penuh: lencana di judul bulan, bukan per catatan.
    expect(ditutup, {'2026-10-01', '2026-10-02'});
    expect(terbuka, containsAll(['2026-10-03', '2026-09-10', '2026-09-20']));
    await gulirKe(tester, find.text('September 2026'));
    expect(
        find.descendant(
            of: find.ancestor(of: find.text('September 2026'), matching: find.byType(Wrap)),
            matching: find.byType(LencanaDitutup)),
        findsOneWidget);
  });

  testWidgets('detail catatan yang ditutup: panel info, tanpa tombol Ubah/Hapus yang pasti ditolak',
      (tester) async {
    final repo = await repoDitutup(sampai: DateTime(2026, 9, 30));
    final modal = (await repo.transactions()).firstWhere((t) => t.txType == TxType.setorModal);
    await pasangHalaman(tester, DetailCatatanPage(catatan: modal, repo: repo), skala: 2.0);
    await semuaTerlihat(tester, ['Ditutup s.d. 30 Sep 2026', 'Sudah ditutup buku', 'Kenapa?']);
    expect(find.text('Ubah'), findsNothing);
    expect(find.text('Hapus'), findsNothing);
    await ketuk(tester, find.text('Kenapa?'));
    await cekLembar(tester, 'Sudah ditutup buku sampai 30 September 2026', 'Lihat Tutup buku di Lainnya');
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail catatan otomatis (tutup buku): panel "Dicatat otomatis", bukan teks abu-abu', (tester) async {
    final repo = await repoDitutup(sampai: DateTime(2026, 9, 30));
    // Tutup buku berikutnya belum ada: entri tutup buku 30 Sep juga di periode yang ditutup.
    final tb = (await repo.transactions()).firstWhere((t) => t.txType == TxType.tutupBuku);
    await pasangHalaman(tester, DetailCatatanPage(catatan: tb, repo: repo), skala: 1.0);
    expect(find.textContaining('Tidak bisa diubah:'), findsNothing);
    await semuaTerlihat(tester, ['Sudah ditutup buku']);
  });

  testWidgets('detail catatan belum ditutup: Ubah dan Hapus tetap ada', (tester) async {
    final repo = await repoDitutup(sampai: DateTime(2026, 9, 30));
    final okt = (await repo.transactions()).firstWhere((t) => t.date == '2026-10-03');
    await pasangHalaman(tester, DetailCatatanPage(catatan: okt, repo: repo), skala: 1.0);
    await semuaTerlihat(tester, ['Ubah', 'Hapus']);
    expect(find.byType(LencanaDitutup), findsNothing);
    expect(find.text('Sudah ditutup buku'), findsNothing);
  });

  testWidgets('Laporan: periode yang mencakup tutup buku berlencana "Ditutup" (ringkasan dan resmi)',
      (tester) async {
    final repo = await repoDitutup(sampai: DateTime(2026, 9, 30));
    await pasangHalaman(tester, ReportPage(repo: repo, hariIni: hariIni), skala: 2.0);
    // Bulan ini (Oktober) belum ditutup.
    expect(find.byType(LencanaDitutup), findsNothing);
    await ketuk(tester, find.text('Bulan lalu'));
    await semuaTerlihat(tester, ['Ditutup s.d. 30 Sep 2026']);
    await ketuk(tester, find.text('Ditutup s.d. 30 Sep 2026'));
    await cekLembar(tester, 'Sudah ditutup buku sampai 30 September 2026', 'Lihat Tutup buku di Lainnya');
    await tutupLembar(tester);

    await tester.tap(find.text('Lihat laporan resmi'));
    await tester.pumpAndSettle();
    expect(find.byType(LaporanResmiPage), findsOneWidget);
    await semuaTerlihat(tester, ['Ditutup s.d. 30 Sep 2026']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lainnya: tutup buku saat sudah ditutup sampai hari ini -> lembar alasan, pintas ke Laporan',
      (tester) async {
    final repo = await repoDitutup(sampai: hariIni);
    await pasangUtama(tester, repo);
    await keTab(tester, 'Lainnya');
    await semuaTerlihat(tester, ['Ditutup s.d. 4 Okt 2026']);
    await ketuk(tester, find.text('Tutup buku'));
    await cekLembar(tester, 'Buku sudah ditutup sampai 4 Oktober 2026', 'Lihat Laporan');
    await tester.tap(find.text('Lihat Laporan'));
    await tester.pumpAndSettle();
    expect(tabTerpilih(tester), TabUtama.laporan);
  });
}
