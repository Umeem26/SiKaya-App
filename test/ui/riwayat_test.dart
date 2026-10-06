// S2: Riwayat catatan dan detail pada 360dp, huruf 1,0x dan 2,0x: arah uang
// ditulis dengan kata, perlu dicek terlihat, tombol Ubah/Hapus berlabel >= 48dp.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/detail_catatan_page.dart';
import 'package:ternak_cibeusi_app/list_finance_page.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';
import 'package:ternak_cibeusi_app/ui/item_catatan.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';

import 'ui_helpers.dart';

/// Semua bentuk baris: masuk, keluar, tidak lewat kas, nilai otomatis, perlu dicek, aset tetap.
Future<AccountingRepository> repoRiwayat() async {
  final repo = await repoUji();
  for (final t in const [
    TransactionModel(txType: TxType.setorModal, amount: 5000000, date: '2026-09-20'),
    TransactionModel(
        txType: TxType.penjualanTunai, amount: 500000, date: '2026-10-01', description: 'Ayam 20 ekor ke Pak Ujang'),
    TransactionModel(
        txType: TxType.bebanOperasional, amount: 200000, date: '2026-10-02', expenseKind: ExpenseKind.listrikAir),
    TransactionModel(txType: TxType.penjualanKredit, amount: 300000, date: '2026-10-03'),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, qty: 999, item: StockItem.obat, date: '2026-10-04'),
  ]) {
    await repo.insertTransaction(t.copyLabel());
  }
  await repo.insertDraft(TxDraft(
    TransactionModel(
        txType: TxType.beliAsetTetap, amount: 1200000, date: '2026-10-04', category: 'Beli kandang/peralatan/kendaraan/tanah'),
    asset: const FixedAssetModel(name: 'Peralatan kandang', lifeMonths: 48),
  ));
  return repo;
}

extension LabelUji on TransactionModel {
  /// Kategori = label spec, seperti hasil form.
  TransactionModel copyLabel() => TransactionModel(
        txType: txType,
        amount: amount,
        date: date,
        qty: qty,
        item: item,
        expenseKind: expenseKind,
        description: description,
        category: txFormSpecs[txType]!.label,
      );
}

void main() {
  for (final skala in skalaUji) {
    testWidgets('Riwayat 360dp huruf ${skala}x: per bulan, arah dengan kata, perlu dicek', (tester) async {
      final repo = await repoRiwayat();
      await pasangHalaman(tester, ListFinancePage(repo: repo), skala: skala);
      await semuaTerlihat(tester, [
        '1 catatan perlu dicek',
        'Tampilkan yang perlu dicek saja',
        'Oktober 2026',
        'Perlu dicek: Jumlah yang dipakai melebihi stok yang tercatat',
        'Nilai dihitung otomatis',
        '4 Okt 2026 · 999 dosis',
        '−Rp1.200.000',
        'Rp300.000',
        'Tidak lewat kas',
        '−Rp200.000',
        'Keluar',
        '+Rp500.000',
        'Masuk',
        'September 2026',
        '+Rp5.000.000',
      ]);
      // Judul catatan: utuh pada huruf normal; pada huruf besar maks. 2 baris ("...").
      for (final judul in [
        'Beli kandang/peralatan/kendaraan/tanah',
        'Jual, belum dibayar (piutang)',
        'Bayar biaya operasional',
        'Jual, dibayar tunai',
      ]) {
        final f = find.text(judul);
        await gulirKe(tester, f);
        if (skala < skalaCatatanBertumpuk) {
          dalamLebar(tester, f);
        } else {
          expect(barisTeks(tester, f), lessThanOrEqualTo(2), reason: judul);
        }
      }
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);

      // Saring: hanya yang perlu dicek.
      await ketuk(tester, find.text('Tampilkan yang perlu dicek saja'));
      expect(find.byType(ItemCatatan), findsOneWidget);
      await ketuk(tester, find.text('Tampilkan semua catatan'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Detail catatan 360dp huruf ${skala}x: rincian, Ubah dan Hapus berlabel', (tester) async {
      final repo = await repoRiwayat();
      final aset = (await repo.transactions()).firstWhere((t) => t.txType == TxType.beliAsetTetap);
      await pasangDitumpuk(tester, DetailCatatanPage(catatan: aset, repo: repo), skala: skala);
      await semuaTerlihat(tester, [
        'Beli kandang/peralatan/kendaraan/tanah',
        '4 Oktober 2026',
        '−Rp1.200.000',
        'Tunai (kas)',
        'Peralatan kandang',
        '48 bulan',
        'Ubah',
        'Hapus',
      ]);
      for (final label in ['Ubah', 'Hapus']) {
        final tombol = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
        await gulirKe(tester, tombol);
        expect(tester.getSize(tombol).height, greaterThanOrEqualTo(48), reason: label);
        expect(find.descendant(of: tombol, matching: find.byType(Icon)), findsOneWidget, reason: label);
      }
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);

      // Hapus aset tetap: dialog menyebut akibatnya, tombol berupa kata kerja.
      await ketuk(tester, find.text('Hapus'));
      expect(find.text('Hapus catatan dan aset tetapnya?'), findsOneWidget);
      expect(find.textContaining('IKUT TERHAPUS'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect((await repo.transactions()).length, 6);
      expect(tester.takeException(), isNull);
    });
  }

  for (final skala in [1.0, 1.3, 2.0]) {
    testWidgets('Baris catatan huruf ${skala}x: nominal ${skala < skalaCatatanBertumpuk ? 'di samping' : 'di bawah'} judul',
        (tester) async {
      const panjang = TransactionModel(
          txType: TxType.beliAsetTetap, amount: 125000000, date: '2026-10-04', category: 'Beli kandang/peralatan/kendaraan/tanah');
      const pendek = TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-10-01');
      aturLayar(tester, skala);
      // Huruf uji (Ahem) jauh lebih lebar dari Roboto: huruf normal diuji di layar lebar
      // agar judul pendek muat berdampingan dengan nominal, seperti di HP.
      if (skala < skalaCatatanBertumpuk) tester.view.physicalSize = const Size(900, tinggiLayar);
      await tester.pumpWidget(MaterialApp(
        theme: temaSikaya(),
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
            ItemCatatan(catatan: panjang.copyLabel(), onTap: () {}),
            ItemCatatan(catatan: pendek.copyLabel(), onTap: () {}),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      for (final (judul, nilai) in [
        ('Beli kandang/peralatan/kendaraan/tanah', '−Rp125.000.000'),
        ('Jual, dibayar tunai', '+Rp500.000'),
      ]) {
        final rJudul = tester.getRect(find.text(judul));
        final rNilai = tester.getRect(find.text(nilai));
        final kartu = tester.getRect(find.ancestor(of: find.text(judul), matching: find.byType(ItemCatatan)));
        if (skala < skalaCatatanBertumpuk) {
          // Nominal sangat lebar (> separuh baris) tetap boleh turun agar judul tidak terjepit.
          if (nilai == '−Rp125.000.000') continue;
          expect(rNilai.left, greaterThan(rJudul.right), reason: '$nilai di samping judul');
          expect(rNilai.top, lessThan(rJudul.bottom), reason: '$nilai sebaris dengan judul');
        } else {
          expect(rNilai.top, greaterThanOrEqualTo(rJudul.bottom), reason: '$nilai di bawah judul');
          expect(barisTeks(tester, find.text(judul)), lessThanOrEqualTo(2));
          // Rata kanan: ujung kanan nominal dekat ujung kanan kartu (sebelum panah).
          expect(kartu.right - rNilai.right, lessThan(48), reason: '$nilai rata kanan');
        }
      }
      // Judul panjang yang dipotong tetap terbaca utuh oleh pembaca layar.
      if (skala >= skalaCatatanBertumpuk) {
        final paragraf = tester.renderObject<RenderParagraph>(find.text('Beli kandang/peralatan/kendaraan/tanah'));
        expect(paragraf.didExceedMaxLines, isTrue);
        expect(paragraf.text.toPlainText(), 'Beli kandang/peralatan/kendaraan/tanah');
      }
      // Nominal: figur tabular.
      final nilaiTeks = tester.widget<Text>(find.text('+Rp500.000'));
      expect(nilaiTeks.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
      cekTinggiKontrol(tester);
      await cekAreaSentuh(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Detail catatan perlu dicek: alasan dalam bahasa petani', (tester) async {
    final repo = await repoRiwayat();
    final obat = (await repo.transactions()).firstWhere((t) => t.perluDitinjau);
    await pasangDitumpuk(tester, DetailCatatanPage(catatan: obat, repo: repo), skala: 2.0);
    await semuaTerlihat(tester, ['Perlu dicek', 'Dihitung otomatis dari harga rata-rata stok', 'Obat & vitamin']);
    final alasan = find.textContaining('Jumlah yang dipakai melebihi stok yang tercatat');
    await gulirKe(tester, alasan);
    dalamLebar(tester, alasan);
    expect(tester.takeException(), isNull);
  });
}
