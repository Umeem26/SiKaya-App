// S4: Lainnya pada 360dp, huruf 1,0x dan 2,0x, dan alurnya: ekspor cadangan
// (tanggal terakhir + pengingat), pulihkan, tutup buku, CSV, nama usaha, hapus semua.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/database/backup.dart';
import 'package:ternak_cibeusi_app/lainnya_page.dart';

import '../accounting/closing_test.dart' show seedCampuran;
import 'ui_helpers.dart';

final hariIni = DateTime(2026, 10, 4);

const ringkasCadangan = BackupSummary(
    versi: 3, transaksi: 9, asetTetap: 1, inventaris: 2, tanggalAwal: '2026-01-02', tanggalAkhir: '2026-01-20');
const ringkasSekarang = BackupSummary(
    versi: 3, transaksi: 12, asetTetap: 1, inventaris: 4, tanggalAwal: '2026-01-02', tanggalAkhir: '2026-02-15');

class Catatan {
  int ekspor = 0, mulaiUlang = 0, hapus = 0;
  String? csv, namaCsv, dipulihkan;
}

LayananLainnya layananPalsu(Catatan c, {String? eksporHasil = 'SiKaya_cadangan_v3.db', bool fileRusak = false}) =>
    LayananLainnya(
      eksporCadangan: () async {
        c.ekspor++;
        return eksporHasil;
      },
      pilihFileCadangan: () async => (path: '/unduhan/cadangan.db', nama: 'cadangan.db'),
      periksaCadangan: (p) async =>
          fileRusak ? throw BackupInvalidException('Bukan file cadangan SiKaya.') : ringkasCadangan,
      ringkasanSekarang: () async => ringkasSekarang,
      pulihkan: (p) async {
        c.dipulihkan = p;
        return const RestoreResult(ringkasCadangan, '/data/sikaya_backup_sebelumpulih.db');
      },
      eksporCsv: (csv, nama) async {
        c.csv = csv;
        c.namaCsv = nama;
        return nama;
      },
      hapusSemua: () async {
        c.hapus++;
        return '/data/sikaya_backup_reset.db';
      },
      mulaiUlang: (_) => c.mulaiUlang++,
    );

Future<(AccountingRepository, Catatan)> pasangLainnya(WidgetTester tester,
    {double skala = 1.0, Map<String, Object> prefs = const {}, bool isi = false, bool fileRusak = false,
    String? eksporHasil = 'SiKaya_cadangan_v3.db', DateTime? hari}) async {
  SharedPreferences.setMockInitialValues({'owner_name': 'Ternak Cibeusi', ...prefs});
  final db = await dbUji();
  final repo = AccountingRepository(() async => db, backup: () async => '/data/sikaya_backup_tutupbuku.db');
  if (isi) await seedCampuran(repo);
  final c = Catatan();
  await pasangHalaman(
      tester,
      LainnyaPage(
          repo: repo,
          hariIni: hari ?? hariIni,
          layanan: layananPalsu(c, fileRusak: fileRusak, eksporHasil: eksporHasil)),
      skala: skala);
  return (repo, c);
}

Future<void> mengerti(WidgetTester tester) async {
  await tester.tap(find.text('Mengerti'));
  await tester.pumpAndSettle();
}

void main() {
  for (final skala in skalaUji) {
    testWidgets('Lainnya 360dp huruf ${skala}x: semua menu berlabel, tanpa overflow', (tester) async {
      await pasangLainnya(tester, skala: skala);
      await semuaTerlihat(tester, [
        'Cadangan & Pengaturan',
        'Belum pernah membuat cadangan',
        'Cadangan terakhir',
        'Belum pernah',
        'Pulihkan cadangan',
        'Tutup buku',
        'Ekspor CSV (untuk Excel)',
        'Nama usaha',
        'Ternak Cibeusi\nKetuk untuk mengubah.',
        'Inventaris',
        'Daftar inventaris',
        'Zona bahaya',
        'Hapus semua data',
      ]);
      final ekspor = find.ancestor(of: find.text('Ekspor cadangan'), matching: find.byType(FilledButton));
      expect(tester.getSize(ekspor).height, greaterThanOrEqualTo(56));
      dalamLebar(tester, ekspor);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ekspor cadangan: tanggal terakhir tersimpan, pengingat hilang; batal = tidak berubah', (tester) async {
    final (_, c) = await pasangLainnya(tester);
    await tester.tap(find.text('Ekspor cadangan'));
    await tester.pumpAndSettle();
    expect(find.text('Cadangan tersimpan'), findsOneWidget);
    expect(find.textContaining('SiKaya_cadangan_v3.db'), findsOneWidget);
    await mengerti(tester);
    expect(c.ekspor, 1);
    await semuaTerlihat(tester, ['4 Oktober 2026 (hari ini)']);
    expect(find.text('Belum pernah membuat cadangan'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(DateTime.parse(prefs.getString(kunciCadanganTerakhir)!), hariIni);
  });

  testWidgets('ekspor dibatalkan: tidak ada pesan, tanggal tidak berubah', (tester) async {
    final (_, c) = await pasangLainnya(tester, eksporHasil: null);
    await tester.tap(find.text('Ekspor cadangan'));
    await tester.pumpAndSettle();
    expect(c.ekspor, 1);
    expect(find.text('Cadangan tersimpan'), findsNothing);
    await semuaTerlihat(tester, ['Belum pernah membuat cadangan']);
  });

  testWidgets('pengingat: muncul bila >= 7 hari, hilang bila baru', (tester) async {
    await pasangLainnya(tester, prefs: {kunciCadanganTerakhir: '2026-09-20T10:00:00'});
    await semuaTerlihat(tester, ['Sudah lama tidak membuat cadangan', '20 September 2026 (14 hari lalu)']);
  });

  testWidgets('pengingat tidak muncul untuk cadangan 3 hari lalu', (tester) async {
    await pasangLainnya(tester, prefs: {kunciCadanganTerakhir: '2026-10-01T08:00:00'});
    await semuaTerlihat(tester, ['1 Oktober 2026 (3 hari lalu)']);
    expect(find.text('Sudah lama tidak membuat cadangan'), findsNothing);
    expect(teksCadanganTerakhir(DateTime(2026, 10, 3, 23), hariIni), '3 Oktober 2026 (kemarin)');
  });

  testWidgets('pulihkan: dialog menyebut isi dan yang hilang, lalu aplikasi dimuat ulang', (tester) async {
    final (_, c) = await pasangLainnya(tester);
    await ketuk(tester, find.text('Pulihkan cadangan'));
    expect(find.text('Pulihkan cadangan ini?'), findsOneWidget);
    expect(find.textContaining('9 catatan, 1 aset tetap, 2 barang inventaris'), findsOneWidget);
    expect(find.textContaining('akan HILANG'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Pulihkan'));
    await tester.pumpAndSettle();
    expect(c.dipulihkan, '/unduhan/cadangan.db');
    expect(find.text('Cadangan dipulihkan'), findsOneWidget);
    await mengerti(tester);
    expect(c.mulaiUlang, 1);
  });

  testWidgets('pulihkan file rusak: ditolak, data tidak diubah', (tester) async {
    final (_, c) = await pasangLainnya(tester, fileRusak: true);
    await ketuk(tester, find.text('Pulihkan cadangan'));
    expect(find.text('File ditolak'), findsOneWidget);
    expect(find.textContaining('Data saat ini tidak diubah.'), findsOneWidget);
    await mengerti(tester);
    expect((c.dipulihkan, c.mulaiUlang), (null, 0));
  });

  testWidgets('tutup buku: pilih tanggal, lewati cadangan, konfirmasi -> periode terkunci', (tester) async {
    final (repo, c) = await pasangLainnya(tester, isi: true, hari: DateTime(2026, 2, 15));
    await semuaTerlihat(tester, [
      'Kunci catatan sampai tanggal tertentu dan pindahkan untung ke saldo laba. Belum pernah ditutup.'
    ]);
    await ketuk(tester, find.text('Tutup buku'));
    // Kalender mulai di akhir bulan lalu (31 Januari).
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(find.text('Ekspor cadangan dulu?'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup buku sampai 31 Januari 2026?'), findsOneWidget);
    expect(find.textContaining('Untung periode ini Rp2.500.000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tutup buku'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup buku selesai'), findsOneWidget);
    await mengerti(tester);
    expect(await repo.lockedUntil(), DateTime(2026, 1, 31));
    expect(c.ekspor, 0);
    await semuaTerlihat(tester, [
      'Kunci catatan sampai tanggal tertentu dan pindahkan untung ke saldo laba. '
          'Sudah ditutup sampai 31 Januari 2026.'
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutup buku dengan "Ekspor cadangan dulu": cadangan dibuat, tanggal terakhir tercatat', (tester) async {
    final (repo, c) = await pasangLainnya(tester, isi: true, hari: DateTime(2026, 2, 15));
    await ketuk(tester, find.text('Tutup buku'));
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekspor cadangan dulu'));
    await tester.pumpAndSettle();
    expect(c.ekspor, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Tutup buku'));
    await tester.pumpAndSettle();
    await mengerti(tester);
    expect(await repo.lockedUntil(), DateTime(2026, 1, 31));
    await semuaTerlihat(tester, ['15 Februari 2026 (hari ini)']);
  });

  testWidgets('ekspor CSV: kolom lama, satu baris per catatan', (tester) async {
    final (_, c) = await pasangLainnya(tester, isi: true);
    await ketuk(tester, find.text('Ekspor CSV (untuk Excel)'));
    expect(find.text('CSV tersimpan'), findsOneWidget);
    await mengerti(tester);
    final baris = c.csv!.trim().split(RegExp(r'\r?\n'));
    expect(baris.first, 'Tanggal,Tipe,Kategori,Nominal,Deskripsi');
    expect(baris, hasLength(10)); // judul + 9 catatan skenario
    expect(c.namaCsv, 'Catatan_SiKaya_20261004.csv');
  });

  testWidgets('ubah nama usaha', (tester) async {
    await pasangLainnya(tester, skala: 2.0);
    await ketuk(tester, find.text('Nama usaha'));
    await tester.enterText(find.byType(TextField), 'Cibeusi Jaya');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    await semuaTerlihat(tester, ['Cibeusi Jaya\nKetuk untuk mengubah.']);
    expect((await SharedPreferences.getInstance()).getString('owner_name'), 'Cibeusi Jaya');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hapus semua data: konfirmasi merah, cadangan dibuat, pengaturan dikosongkan', (tester) async {
    final (_, c) = await pasangLainnya(tester);
    await ketuk(tester, find.text('Hapus semua data'));
    expect(find.text('Hapus semua data?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(c.hapus, 0);
    await ketuk(tester, find.text('Hapus semua data'));
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus semuanya'));
    await tester.pumpAndSettle();
    expect((c.hapus, c.mulaiUlang), (1, 1));
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  testWidgets('dialog cadangan & pulihkan pada huruf 2,0x: semua tombol terlihat dan >= 48dp', (tester) async {
    await pasangLainnya(tester, skala: 2.0, isi: true, hari: DateTime(2026, 2, 15));
    void cekTombol(List<String> label) {
      for (final l in label) {
        final b = find.ancestor(of: find.text(l), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).last;
        final r = tester.getRect(b);
        expect(r.height, greaterThanOrEqualTo(48), reason: l);
        expect(r.left >= 0 && r.right <= lebarLayar && r.top >= 0 && r.bottom <= tinggiLayar, isTrue, reason: '$l di luar layar');
      }
    }

    await ketuk(tester, find.text('Tutup buku'));
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    cekTombol(['Batal', 'Lewati', 'Ekspor cadangan dulu']);
    await tester.tap(find.text('Batal').last);
    await tester.pumpAndSettle();

    await ketuk(tester, find.text('Pulihkan cadangan'));
    cekTombol(['Batal', 'Pulihkan']);
    expect(tester.takeException(), isNull);
  });
}
