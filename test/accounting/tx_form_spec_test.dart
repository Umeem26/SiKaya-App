// Tabel konfigurasi form (bagian A): setiap tipe punya spec; spec manual menghasilkan
// transaksi yang valid dan diterima mesin (tidak perlu_ditinjau) lewat jalur DB yang
// sama dengan form.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/accounting/tx_form_spec.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'db_helpers.dart';
import 'helpers.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late AccountingRepository repo;

  setUp(() async {
    db = await openMemoryDb();
    repo = AccountingRepository(() async => db);
  });
  tearDown(() => db.close());

  /// Stok dan piutang awal agar pakai/kematian/terima piutang/retur punya rujukan.
  Future<void> seed() async {
    for (final t in [
      const TransactionModel(txType: TxType.setorModal, amount: 10000000, date: '2026-03-01'),
      const TransactionModel(
          txType: TxType.beliPersediaanTunai, amount: 1000000, date: '2026-03-01', qty: 100, item: StockItem.pakan),
      const TransactionModel(
          txType: TxType.beliPersediaanTunai, amount: 2000000, date: '2026-03-01', qty: 100, item: StockItem.ternak),
      const TransactionModel(txType: TxType.penjualanKredit, amount: 1000000, date: '2026-03-01'),
    ]) {
      await repo.insertTransaction(t);
    }
  }

  Future<FormInput> isiContoh(TxTypeFormSpec spec, {int? asal}) async {
    final ref = await repo.rujukan();
    final rujukan = {for (final r in [...ref.piutang, ...ref.retur]) r.id: r};
    final values = <FieldKey, Object?>{
      for (final f in spec.fields)
        f.key: switch (f.key) {
          FieldKey.tanggal => '2026-03-10',
          FieldKey.nominal => asal == null ? 100000 : rujukan[asal]!.sisa,
          FieldKey.qty => 10,
          FieldKey.item || FieldKey.jenisBeban || FieldKey.sumberBayar => f.pilihan.first.value,
          FieldKey.rujukanPiutang => ref.piutang.first.id,
          FieldKey.transaksiAsal => asal,
          FieldKey.namaAset => 'Kandang',
          FieldKey.umurBulan => 12,
          FieldKey.tanggalSiapPakai || FieldKey.keterangan => null,
        },
    };
    return FormInput(values, rujukan: rujukan);
  }

  test('setiap tipe punya spec; spec manual -> transaksi valid diterima mesin', () async {
    await seed();
    expect(txFormSpecs.keys.toSet(), TxType.values.toSet()); // 16 tipe
    for (final type in TxType.values) {
      final spec = txFormSpecs[type]!;
      expect(spec.type, type);
      if (!spec.manual) {
        expect([TxType.penyusutan, TxType.tutupBuku], contains(type)); // dihitung mesin / menu tutup buku
        expect(() => buildDraft(spec, FormInput({})), throwsA(isA<FormInvalidException>()));
        continue;
      }
      final input = await isiContoh(spec);
      expect(validateForm(spec, input), isEmpty, reason: type.code);
      final id = await repo.insertDraft(buildDraft(spec, input));
      final row = (await repo.transactionById(id))!;
      expect(row.txType, type);
      expect(row.perluDitinjau, isFalse, reason: '${type.code}: ${row.reviewNote}');
      final r = (await repo.loadReport(asOf: d('2026-03-31'))).report;
      expect(r.perluDitinjau, isEmpty, reason: type.code);
      expect(r.balanced, isTrue, reason: type.code);
    }
    // penyusutan dihitung mesin dari aset yang dibuat form beli_aset_tetap
    final r = (await repo.loadReport(asOf: d('2026-03-31'))).report;
    expect(r.asetTetapBruto, 100000); // harga beli contoh
    expect(r.akumulasiPenyusutan, 8333); // 100.000/12 = 8.333,3 -> 8.333 (1 bulan, Maret)
  });

  test('beli_aset_tetap membuat aset + transaksi sekaligus; siap pakai kosong = tanggal beli', () async {
    final spec = txFormSpecs[TxType.beliAsetTetap]!;
    final id = await repo.insertDraft(buildDraft(spec, await isiContoh(spec)));
    final row = (await repo.transactionById(id))!;
    final aset = (await repo.fixedAssets()).single;
    expect(row.assetId, aset.id);
    expect(aset.name, 'Kandang');
    expect(aset.lifeMonths, 12);
    expect(aset.readyDate, isNull); // repository memakai tanggal transaksi
  });

  test('retur: setiap tipe yang bisa diretur, retur = sisa diterima; melebihi sisa ditolak form', () async {
    await seed();
    for (final type in tipeBisaDiretur) {
      final spec = txFormSpecs[type]!;
      final asalId = await repo.insertDraft(buildDraft(spec, await isiContoh(spec)));
      final lebih = await isiContoh(returFormSpec, asal: asalId);
      lebih.values[FieldKey.nominal] = (lebih.values[FieldKey.nominal] as int) + 1;
      expect(validateForm(returFormSpec, lebih)[FieldKey.nominal], startsWith('Melebihi sisa'),
          reason: type.code);

      final draft = buildDraft(returFormSpec, await isiContoh(returFormSpec, asal: asalId));
      expect(draft.tx.txType, type);
      expect(draft.tx.reversalOf, asalId);
      final row = (await repo.transactionById(await repo.insertDraft(draft)))!;
      expect(row.perluDitinjau, isFalse, reason: '${type.code}: ${row.reviewNote}');
      expect((await repo.rujukan()).retur.where((r) => r.id == asalId), isEmpty); // sisa 0
    }
    final r = (await repo.loadReport(asOf: d('2026-03-31'))).report;
    expect(r.perluDitinjau, isEmpty);
    expect(r.balanced, isTrue);
  });

  test('field wajib kosong dan nominal 0 ditolak; pemakaian > stok tetap boleh disimpan', () async {
    final jual = txFormSpecs[TxType.penjualanTunai]!;
    expect(validateForm(jual, FormInput({})).keys, {FieldKey.tanggal, FieldKey.nominal});
    expect(validateForm(jual, FormInput({FieldKey.tanggal: '2026-03-10', FieldKey.nominal: 0})),
        contains(FieldKey.nominal));
    expect(validateForm(jual, FormInput({FieldKey.tanggal: '2026-02-30', FieldKey.nominal: 1})),
        contains(FieldKey.tanggal)); // tanggal tidak ada

    await seed();
    final pakai = txFormSpecs[TxType.pakaiPersediaan]!;
    final input = await isiContoh(pakai);
    input.values[FieldKey.qty] = 120; // stok pakan 100
    expect(validateForm(pakai, input), isEmpty);
    final row = (await repo.transactionById(await repo.insertDraft(buildDraft(pakai, input))))!;
    expect(row.perluDitinjau, isTrue); // ditandai mesin, tidak ditolak form
  });
}
