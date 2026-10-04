// Satu sumber kebenaran angka keuangan: baris DB -> TransactionModel -> mesin.
// Dashboard, daftar keuangan, dan halaman laporan membaca dari sini.
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../transaction_model.dart';
import 'engine.dart';
import 'models.dart';

/// Hasil satu periode laporan.
class PeriodReport {
  final DateTime? from;
  final DateTime asOf;
  final Report report;

  /// Buku kas (dihitung terpisah dari `report`, invarian D3).
  final CashSummary kas;
  const PeriodReport(this.from, this.asOf, this.report, this.kas);
}

class AccountingRepository {
  AccountingRepository(this._open);

  final Future<Database> Function() _open;

  static final AccountingRepository instance =
      AccountingRepository(() => DatabaseHelper.instance.database);

  Future<List<TransactionModel>> transactions() async {
    final db = await _open();
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<FixedAssetModel>> fixedAssets() async {
    final db = await _open();
    final rows = await db.query('fixed_assets', orderBy: 'id');
    return rows.map(FixedAssetModel.fromMap).toList();
  }

  Future<int> insertFixedAsset(FixedAssetModel asset) async {
    final db = await _open();
    return db.insert('fixed_assets', asset.toMap()..remove('id'));
  }

  /// Simpan transaksi (termasuk yang nantinya ditandai perlu_ditinjau), lalu
  /// perbarui kolom perlu_ditinjau seluruh baris.
  Future<int> insertTransaction(TransactionModel t) async {
    final db = await _open();
    final id = await db.insert('transactions', _writable(t));
    await syncReviewFlags();
    return id;
  }

  /// Gagal (DatabaseException) bila baris dirujuk retur/pelunasan lain.
  Future<void> deleteTransaction(int id) async {
    final db = await _open();
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await syncReviewFlags();
  }

  /// Laporan satu periode: Laba Rugi [from, asOf] (from null = sejak awal),
  /// Posisi Keuangan per asOf, ditambah ringkasan buku kas per asOf.
  Future<PeriodReport> loadReport({required DateTime asOf, DateTime? from}) async {
    final input = buildEngineInput(await transactions(), await fixedAssets());
    return PeriodReport(
      from,
      asOf,
      buildReport(input.txs, input.assets, asOf: asOf, from: from),
      cashBookSummary(input.txs, asOf: asOf),
    );
  }

  /// Kolom perlu_ditinjau/review_note = cermin hasil mesin atas seluruh riwayat.
  /// Status satu baris tidak bergantung pada asOf laporan selama asOf >= tanggalnya.
  Future<void> syncReviewFlags() async {
    final db = await _open();
    final input = buildEngineInput(await transactions(), await fixedAssets());
    final flags = buildReport(input.txs, input.assets, asOf: DateTime(9999, 12, 31))
        .perluDitinjau;
    await db.transaction((txn) async {
      final batch = txn.batch()
        ..update('transactions', {'perlu_ditinjau': 0, 'review_note': null},
            where: 'perlu_ditinjau = 1 OR review_note IS NOT NULL');
      for (final f in flags) {
        batch.update('transactions',
            {'perlu_ditinjau': 1, 'review_note': '${f.reason.name}: ${f.detail}'},
            where: 'id = ?', whereArgs: [f.txId]);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Ubah baris DB menjadi input mesin. Harga perolehan aset tetap diambil dari
  /// transaksi beli_aset_tetap yang menautkannya; aset tanpa transaksi beli tidak dihitung.
  static ({List<AcctTx> txs, List<FixedAsset> assets}) buildEngineInput(
    List<TransactionModel> rows,
    List<FixedAssetModel> assets,
  ) {
    final beli = <int, TransactionModel>{
      for (final r in rows)
        if (r.txType == TxType.beliAsetTetap && r.reversalOf == null && r.assetId != null)
          r.assetId!: r,
    };
    return (
      txs: [for (final r in rows) r.toAcctTx()],
      assets: [
        for (final a in assets)
          if (beli[a.id] != null)
            FixedAsset(
              id: a.id!,
              name: a.name,
              cost: beli[a.id]!.amount,
              readyDate: DateTime.parse(a.readyDate ?? beli[a.id]!.date),
              lifeMonths: a.lifeMonths,
            ),
      ],
    );
  }

  /// Kolom perlu_ditinjau/review_note hanya ditulis oleh syncReviewFlags.
  static Map<String, Object?> _writable(TransactionModel t) => t.toMap()
    ..remove('id')
    ..remove('perlu_ditinjau')
    ..remove('review_note');
}
