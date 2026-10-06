// Alat bantu integration test: mencari isian form, mengisi catatan lewat
// "Apa yang terjadi?", dan titik foto untuk tangkapan layar otomatis.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/halaman_utama.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';

/// `--dart-define=SIKAYA_FOTO=true`: berhenti di titik foto dan menunggu
/// skrip host (tool/tangkap_layar.sh) mengambil gambar lewat adb.
const modeFoto = bool.fromEnvironment('SIKAYA_FOTO');

/// pumpAndSettle dengan batas 30 detik: animasi tanpa akhir jadi error, bukan macet.
Future<void> tenang(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));

/// Tunggu waktu nyata sambil terus menggambar frame (binding live).
Future<void> jeda(WidgetTester tester, [int ms = 600]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tenang(tester);
}

/// Kirim [pesan] ke host lewat logcat lalu tunggu file balasan
/// `files/foto_ok_<id>` yang dibuat host dengan `adb shell run-as`.
Future<void> _mintaHost(WidgetTester tester, String pesan, String id) async {
  final ok = File('${(await getApplicationSupportDirectory()).path}/foto_ok_$id');
  if (ok.existsSync()) ok.deleteSync();
  debugPrint('SIKAYA_HOST:$pesan');
  final batas = DateTime.now().add(const Duration(seconds: 60));
  while (!ok.existsSync()) {
    if (DateTime.now().isAfter(batas)) fail('host tidak menjawab "$pesan"');
    await tester.pump(const Duration(milliseconds: 250));
  }
  ok.deleteSync();
  await tenang(tester);
}

/// Titik foto: no-op kecuali [modeFoto].
Future<void> foto(WidgetTester tester, String nama) async {
  if (!modeFoto) return;
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await jeda(tester, 1200); // jejak ketukan dan animasi selesai
  await _mintaHost(tester, 'foto:$nama', nama);
}

/// Ubah ukuran huruf sistem (settings font_scale) lewat host. No-op kecuali [modeFoto].
Future<void> hurufSistem(WidgetTester tester, String skala) async {
  if (!modeFoto) return;
  await _mintaHost(tester, 'huruf:$skala', 'huruf_$skala');
  await jeda(tester, 1500);
}

/// Mulai/hentikan rekaman layar oleh host. No-op kecuali [modeFoto].
Future<void> rekam(WidgetTester tester, bool mulai) async {
  if (!modeFoto) return;
  await _mintaHost(tester, mulai ? 'rekam:mulai' : 'rekam:selesai', mulai ? 'rekam_mulai' : 'rekam_selesai');
}

/// Jeda agar rekaman bisa diikuti mata; tanpa [modeFoto] tidak menunggu.
Future<void> pelan(WidgetTester tester) async {
  if (modeFoto) await jeda(tester, 900);
}

Finder navigasi(String label) =>
    find.descendant(of: find.byType(NavigasiBawah), matching: find.text(label));

Future<void> keTab(WidgetTester tester, String label) async {
  await tester.tap(navigasi(label));
  await tenang(tester);
  await tungguMuat(tester);
}

/// Daftar gulir vertikal halaman teratas.
Finder daftarUtama() =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Finder `.first`/`.last` melempar StateError bila kosong; anggap belum ada.
bool _belumAda(Finder f) {
  try {
    return f.evaluate().isEmpty;
  } on StateError {
    return true;
  }
}

/// Tunggu (waktu nyata) sampai [syarat] benar; operasi DB/berkas berjalan di
/// luar frame, jadi pumpAndSettle bisa selesai lebih dulu.
Future<void> tungguSampai(WidgetTester tester, bool Function() syarat, String apa, {int detik = 30}) async {
  final batas = DateTime.now().add(Duration(seconds: detik));
  while (!syarat()) {
    if (DateTime.now().isAfter(batas)) fail('menunggu terlalu lama: $apa');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tenang(tester);
}

Future<void> tunggu(WidgetTester tester, Finder f) => tungguSampai(tester, () => !_belumAda(f), '$f');

Future<void> tungguHilang(WidgetTester tester, Finder f) =>
    tungguSampai(tester, () => _belumAda(f), 'hilang: $f');

/// Halaman yang sedang memuat (FutureBuilder) menampilkan indikator putar.
Future<void> tungguMuat(WidgetTester tester) => tungguHilang(tester, find.byType(CircularProgressIndicator));

/// Gulir daftar utama sampai [f] dibangun, lalu pastikan terlihat.
Future<void> gulirKe(WidgetTester tester, Finder f) async {
  await tungguMuat(tester);
  if (_belumAda(f)) {
    final pos = tester.state<ScrollableState>(daftarUtama().first).position;
    pos.jumpTo(0);
    await tester.pump();
    while (_belumAda(f) && pos.pixels < pos.maxScrollExtent) {
      pos.jumpTo((pos.pixels + 200).clamp(0, pos.maxScrollExtent));
      await tester.pump();
    }
  }
  expect(f, findsWidgets, reason: '$f tidak ditemukan sesudah digulir');
  await Scrollable.ensureVisible(f.evaluate().first, alignment: 0.3);
  await tenang(tester);
}

Future<void> ketuk(WidgetTester tester, Finder f) async {
  await gulirKe(tester, f);
  await tester.tap(f.first);
  await tenang(tester);
}

Future<void> keAtas(WidgetTester tester) async {
  final s = daftarUtama();
  if (s.evaluate().isEmpty) return;
  tester.state<ScrollableState>(s.last).position.jumpTo(0);
  await tenang(tester);
}

/// TextField di bawah label [label] (LabelIsian).
Finder isian(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(LabelIsian)).first,
    matching: find.byType(TextField));

final isianRupiah = find.descendant(of: find.byType(InputRupiah), matching: find.byType(TextField));

Future<void> isi(WidgetTester tester, Finder f, String teks) async {
  await gulirKe(tester, f);
  await tester.enterText(f.first, teks);
  await tenang(tester);
}

/// Pilih tanggal [t] lewat "Pilih tanggal" (kalender, mode ketik). Format
/// tanggal dialog = lokal bawaan aplikasi (en_US, MM/dd/yyyy).
Future<void> pilihTanggal(WidgetTester tester, DateTime t, {String label = 'Tanggal'}) async {
  await gulirKe(tester, find.text(label));
  final isianTanggal = find.ancestor(of: find.text(label), matching: find.byType(InputTanggal));
  await ketuk(tester, find.descendant(of: isianTanggal.first, matching: find.text('Pilih tanggal')));
  await tester.tap(find.byTooltip('Switch to input'));
  await tenang(tester);
  final mm = t.month.toString().padLeft(2, '0'), dd = t.day.toString().padLeft(2, '0');
  await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '$mm/$dd/${t.year}');
  await tester.tap(find.text('Pilih'));
  await tenang(tester);
}

/// Satu catatan lewat tombol "Apa yang terjadi?". [pilihan] diketuk berurutan
/// (barang, jenis biaya, cara bayar, rujukan); [teks] = label isian -> nilai.
Future<void> catat(
  WidgetTester tester,
  String jenis, {
  DateTime? tanggal,
  List<String> pilihan = const [],
  Map<String, String> teks = const {},
  int? nominal,
  String? fotoPilihan,
  String? fotoForm,
}) async {
  debugPrint('LANGKAH catat: $jenis');
  await tester.tap(find.text('Apa yang terjadi?').last);
  await tenang(tester);
  expect(find.byType(FormFinancePage), findsOneWidget);
  await tungguMuat(tester);
  if (fotoPilihan != null) await foto(tester, fotoPilihan);
  await pelan(tester);
  await ketuk(tester, find.text(jenis));
  await pelan(tester);
  if (tanggal != null) await pilihTanggal(tester, tanggal);
  for (final e in teks.entries) {
    await gulirKe(tester, find.text(e.key)); // daftar malas: label dibangun dulu
    await isi(tester, isian(e.key), e.value);
  }
  for (final p in pilihan) {
    await ketuk(tester, find.text(p).last);
  }
  if (nominal != null) await isi(tester, isianRupiah, '$nominal');
  await pelan(tester);
  if (fotoForm != null) {
    await keAtas(tester);
    await foto(tester, fotoForm);
  }
  await tester.tap(find.text('Simpan'));
  await tungguSampai(
      tester,
      () => _belumAda(find.byType(FormFinancePage)) ||
          !_belumAda(find.text('Tersimpan, tetapi perlu dicek')) ||
          !_belumAda(find.text('Tidak bisa disimpan')),
      'simpan $jenis');
  await tungguMuat(tester);
  expect(find.text('Tersimpan, tetapi perlu dicek'), findsNothing, reason: '$jenis perlu dicek');
  expect(find.text('Tidak bisa disimpan'), findsNothing, reason: '$jenis ditolak');
  if (find.byType(FormFinancePage).evaluate().isNotEmpty) {
    final teksLayar = [
      for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? '',
    ];
    fail('$jenis belum tersimpan; teks di layar: $teksLayar');
  }
  tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).clearSnackBars();
  await tenang(tester);
}

/// Teks di dalam KartuAngka berjudul [judul] (gulir dulu).
Future<void> cekKartu(WidgetTester tester, String judul, String nilai) async {
  final k = find.ancestor(of: find.text(judul), matching: find.byType(KartuAngka));
  await gulirKe(tester, k);
  expect(find.descendant(of: k.first, matching: find.text(nilai)), findsOneWidget, reason: '$judul = $nilai');
}

/// Nilai BarisLaporan berlabel [label] sama dengan [nilai].
Future<void> cekBaris(WidgetTester tester, String label, String nilai) async {
  final b = find.ancestor(of: find.text(label), matching: find.byType(BarisLaporan));
  await gulirKe(tester, b);
  expect(find.descendant(of: b.first, matching: find.text(nilai)), findsOneWidget, reason: '$label = $nilai');
}
