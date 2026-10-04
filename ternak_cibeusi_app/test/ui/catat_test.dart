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
