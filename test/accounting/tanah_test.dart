// Tanah (SAK EMKM B2): umur manfaat opsional lewat pilihan "tidak disusutkan".
// Mesin tidak menyusutkan aset tanpa umur; aset tercatat utuh di Posisi Keuangan.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/engine.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'db_helpers.dart';
import 'helpers.dart';

void main() {
  sqfliteFfiInit();
  final spec = txFormSpecs[TxType.beliAsetTetap]!;

  FormInput isi(Object? umur, {String nama = 'Tanah kandang', int harga = 50000000}) =>
      FormInput({
        FieldKey.namaAset: nama,
        FieldKey.tanggal: '2026-01-15',
        FieldKey.nominal: harga,
        FieldKey.sumberBayar: PaymentSource.kas,
        FieldKey.umurBulan: umur,
      });

  group('form', () {
    test('umur kosong tetap ditolak: harus angka atau "tidak disusutkan"', () {
      expect(validateForm(spec, isi(null))[FieldKey.umurBulan], 'Umur manfaat (bulan) wajib diisi');
      expect(validateForm(spec, isi(0)), contains(FieldKey.umurBulan));
      expect(validateForm(spec, isi('tanah')), contains(FieldKey.umurBulan)); // bukan nilai khusus
      expect(validateForm(spec, isi(UmurManfaat.tidakDisusutkan)), isEmpty);
    });

    test('tidak disusutkan -> lifeMonths null; mode ubah memulihkan pilihan', () {
      final draft = buildDraft(spec, isi(UmurManfaat.tidakDisusutkan));
      expect(draft.asset!.lifeMonths, isNull);
      expect(valuesFrom(draft.tx, asset: draft.asset)[FieldKey.umurBulan],
          UmurManfaat.tidakDisusutkan);
      expect(buildDraft(spec, isi(96)).asset!.lifeMonths, 96);
    });
  });

  group('mesin', () {
    final tanah = FixedAsset(id: 1, name: 'Tanah', cost: 50000000, readyDate: d('2026-01-15'));

    test('aset tanpa umur (null/0/negatif) tidak disusutkan', () {
      for (final life in [null, 0, -12]) {
        final a = FixedAsset(id: 1, name: 'x', cost: 1000, readyDate: d('2026-01-01'), lifeMonths: life);
        expect(depreciationSchedule(a), isEmpty, reason: '$life');
        expect(accumulatedDepreciation(a, d('2060-12-31')), 0, reason: '$life');
      }
    });

    test('tanah: penyusutan 0, tercatat utuh; aset lain tetap disusutkan', () {
      final txs = [
        tx(1, '2026-01-02', TxType.setorModal, amount: 60000000),
        tx(2, '2026-01-15', TxType.beliAsetTetap, amount: 50000000, assetId: 1),
        tx(3, '2026-01-20', TxType.beliAsetTetap, amount: 1200000, assetId: 2),
      ];
      final assets = [
        tanah,
        FixedAsset(id: 2, name: 'Peralatan', cost: 1200000, readyDate: d('2026-01-20'), lifeMonths: 12),
      ];
      // 10 tahun kemudian: peralatan habis disusutkan, tanah tetap 50.000.000.
      final r = buildReport(txs, assets, asOf: d('2036-01-31'), from: d('2036-01-01'));
      expect(r.asetTetapBruto, 51200000);
      expect(r.akumulasiPenyusutan, 1200000); // hanya peralatan
      expect(r.asetTetapNeto, 50000000); // tanah utuh
      expect(r.beban[ExpenseKind.penyusutan], isNull); // tidak ada penyusutan periode ini
      expect(r.totalAset, 60000000 - 51200000 + 50000000);
      expect(r.balanced, isTrue);

      final hanyaTanah = buildReport(txs.take(2).toList(), [tanah], asOf: d('2040-12-31'));
      expect(hanyaTanah.akumulasiPenyusutan, 0);
      expect(hanyaTanah.beban, isEmpty);
      expect(hanyaTanah.labaBersih, 0);
      expect(hanyaTanah.totalAset, 60000000); // kas 10.000.000 + tanah 50.000.000
      expect(hanyaTanah.balanced, isTrue);
    });
  });

  test('lewat form + DB: tanah tersimpan tanpa umur dan tidak disusutkan', () async {
    final db = await openMemoryDb();
    addTearDown(db.close);
    final repo = AccountingRepository(() async => db);
    await repo.insertTransaction(
        const TransactionModel(txType: TxType.setorModal, amount: 60000000, date: '2026-01-02'));
    await repo.insertDraft(buildDraft(spec, isi(UmurManfaat.tidakDisusutkan)));

    final aset = (await repo.fixedAssets()).single;
    expect(aset.lifeMonths, isNull);
    final r = (await repo.loadReport(asOf: d('2030-06-30'), from: d('2026-01-01'))).report;
    expect(r.asetTetapBruto, 50000000);
    expect(r.akumulasiPenyusutan, 0);
    expect(r.beban, isEmpty);
    expect(r.totalAset, 60000000);
    expect(r.perluDitinjau, isEmpty);
    expect(r.balanced, isTrue);
  });
}
