// S2: layar "Apa yang terjadi?" berkelompok dan form tiap jenis catatan pada
// 360dp, huruf 1,0x dan 2,0x: tanpa overflow, label terlihat, area sentuh >= 48dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/form_finance_page.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';
import 'package:ternak_cibeusi_app/ui/komponen.dart';
import 'package:ternak_cibeusi_app/ui/tokens.dart';

import 'ui_helpers.dart';

final hariIni = DateTime(2026, 10, 4);

/// Satu penjualan kredit agar "Terima pembayaran piutang" dan retur bisa dipilih.
Future<AccountingRepository> repoBerisi() async {
  final repo = await repoUji();
  await repo.insertTransaction(
      const TransactionModel(txType: TxType.penjualanKredit, amount: 300000, date: '2026-10-01'));
  return repo;
}

Future<void> bukaCatat(WidgetTester tester, AccountingRepository repo, double skala) =>
    pasangDitumpuk(tester, FormFinancePage(repo: repo, hariIni: hariIni), skala: skala);

void main() {
  test('setiap jenis catatan muncul tepat sekali di kelompok', () {
    final semua = [for (final k in kelompokCatat) ...k.pilihan];
    expect(semua.toSet(), {...txFormSpecs.values, returFormSpec});
    expect(semua.length, txFormSpecs.length + 1);
  });

  for (final skala in skalaUji) {
    testWidgets('"Apa yang terjadi?" 360dp huruf ${skala}x: kelompok, pilihan, alasan nonaktif',
        (tester) async {
      await bukaCatat(tester, await repoBerisi(), skala);
      expect(MediaQuery.textScalerOf(tester.element(find.byType(FormFinancePage))).scale(10), 10 * skala);
      await semuaTerlihat(tester, [
        for (final k in kelompokCatat) ...[k.judul, for (final s in k.pilihan) s.label],
      ]);
      // Yang otomatis tetap tampil, dengan alasan.
      for (final s in [txFormSpecs[TxType.penyusutan]!, txFormSpecs[TxType.tutupBuku]!]) {
        await semuaTerlihat(tester, ['Belum bisa dipilih: ${s.otomatis}']);
      }
      expect(find.byType(KartuPilihan), findsWidgets);
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('form setiap jenis catatan, 360dp huruf ${skala}x: label terlihat, tanpa overflow',
        (tester) async {
      final repo = await repoBerisi();
      await bukaCatat(tester, repo, skala);
      for (final k in kelompokCatat) {
        for (final s in k.pilihan.where((s) => s.manual)) {
          await ketuk(tester, find.text(s.label));
          expect(find.widgetWithText(AppBar, 'Catat'), findsOneWidget, reason: s.label);

          // Tombol Simpan selalu terlihat (di luar daftar yang digulir), tinggi >= 56dp.
          final simpan = find.ancestor(of: find.text('Simpan'), matching: find.byType(FilledButton));
          expect(tester.getSize(simpan).height, greaterThanOrEqualTo(56));
          dalamLebar(tester, simpan);

          await semuaTerlihat(tester, [
            s.label,
            for (final f in s.fields) f.wajib ? f.label : '${f.label} (boleh kosong)',
          ]);
          cekTinggiKontrol(tester);
          if (skala == 2.0) await cekAreaSentuh(tester);
          expect(tester.takeException(), isNull, reason: s.label);

          await ketuk(tester, find.text('Ganti pilihan'));
        }
      }
    });
  }

  test('setiap isian setiap jenis masuk tepat satu langkah, urutan langkah tetap', () {
    for (final s in [...txFormSpecs.values, returFormSpec].where((s) => s.manual)) {
      expect(s.field(FieldKey.keterangan), isNotNull, reason: s.label);
      expect(langkahIsian(FieldKey.keterangan), LangkahCatat.catatan);
      expect(judulLangkah(LangkahCatat.kapan, s),
          s.field(FieldKey.sumberBayar) == null ? 'Kapan' : 'Kapan dan dibayar bagaimana');
    }
  });

  for (final skala in skalaUji) {
    testWidgets('form beli aset ${skala}x: kartu per langkah berurutan, label di atas, isian terisi', (tester) async {
      await bukaCatat(tester, await repoBerisi(), skala);
      await ketuk(tester, find.text('Beli kandang/peralatan/kendaraan/tanah'));
      final judul = ['Apa yang dicatat', 'Berapa', 'Kapan dan dibayar bagaimana', 'Catatan tambahan'];
      expect(find.byType(KartuLangkah), findsNWidgets(4));
      var atas = double.negativeInfinity;
      for (final j in judul) {
        await gulirKe(tester, find.text(j));
        dalamLebar(tester, find.text(j));
        final y = tester.getTopLeft(find.text(j)).dy +
            tester.state<ScrollableState>(daftarUtama().first).position.pixels;
        expect(y, greaterThan(atas), reason: '$j berurutan');
        atas = y;
      }
      // Label isian di atas kotaknya, di dalam kartu langkahnya.
      for (final (label, langkah) in [
        ('Nama aset', 'Apa yang dicatat'),
        ('Harga beli (Rp)', 'Berapa'),
        ('Cara bayar', 'Kapan dan dibayar bagaimana'),
        ('Catatan (boleh kosong)', 'Catatan tambahan'),
      ]) {
        await gulirKe(tester, find.text(label));
        final kartu = find.ancestor(of: find.text(label), matching: find.byType(KartuLangkah));
        expect(find.descendant(of: kartu, matching: find.text(langkah)), findsOneWidget, reason: label);
      }
      // Isian terisi bersudut bulat tanpa garis tepi saat tidak difokus.
      for (final e in find.byType(InputDecorator, skipOffstage: false).evaluate()) {
        final d = (e.widget as InputDecorator).decoration.applyDefaults(Theme.of(e).inputDecorationTheme);
        expect(d.filled, isTrue);
        expect(d.fillColor, Warna.isian);
        expect(d.enabledBorder, isA<OutlineInputBorder>().having((b) => b.borderSide.style, 'garis', BorderStyle.none));
        expect((d.enabledBorder! as OutlineInputBorder).borderRadius, BorderRadius.circular(Sudut.kecil));
      }
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('jual tunai: tanpa cara bayar, langkah "Kapan"; isian salah digulir terlihat', (tester) async {
    final repo = await repoUji();
    await bukaCatat(tester, repo, 2.0);
    await ketuk(tester, find.text('Jual, dibayar tunai'));
    await semuaTerlihat(tester, ['Apa yang dicatat', 'Berapa', 'Kapan', 'Catatan tambahan']);
    expect(find.text('Kapan dan dibayar bagaimana'), findsNothing);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final salah = find.text('Nominal (Rp) wajib diisi');
    expect(salah, findsOneWidget);
    final r = tester.getRect(salah);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(tinggiLayar));
  });

  testWidgets('Simpan dengan isian kosong: pesan salah tampil, tidak ada yang tersimpan', (tester) async {
    final repo = await repoUji();
    await bukaCatat(tester, repo, 2.0);
    await ketuk(tester, find.text('Jual, dibayar tunai'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await semuaTerlihat(tester, ['1 isian perlu diperbaiki', 'Nominal (Rp) wajib diisi']);
    expect(await repo.transactions(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanggal default hari ini; tombol "Kemarin" mengubah tanggal yang disimpan', (tester) async {
    final repo = await repoUji();
    await bukaCatat(tester, repo, 1.0);
    await ketuk(tester, find.text('Masukkan uang pribadi ke usaha (modal)'));
    expect(find.text('Minggu, 4 Oktober 2026 (hari ini)'), findsOneWidget);
    await ketuk(tester, find.text('Kemarin'));
    expect(find.text('Sabtu, 3 Oktober 2026 (kemarin)'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(InputRupiah), matching: find.byType(TextField)), '1000000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final t = (await repo.transactions()).single;
    expect((t.txType, t.amount, t.date), (TxType.setorModal, 1000000, '2026-10-03'));
  });
}
