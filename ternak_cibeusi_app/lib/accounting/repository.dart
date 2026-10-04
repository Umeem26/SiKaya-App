// Satu sumber kebenaran angka keuangan: baris DB -> TransactionModel -> mesin.
// Dashboard, daftar keuangan, dan halaman laporan membaca dari sini.
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../transaction_model.dart';
import 'engine.dart';
import 'models.dart';
import 'tx_form_spec.dart';

/// Hasil satu periode laporan.
class PeriodReport {
  final DateTime? from;
  final DateTime asOf;
  final Report report;

  /// Buku kas (dihitung terpisah dari `report`, invarian D3).
  final CashSummary kas;

  /// Posisi per sehari sebelum `from`; null bila `from` null.
  final Report? opening;
  const PeriodReport(this.from, this.asOf, this.report, this.kas, {this.opening});
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

  Future<TransactionModel?> transactionById(int id) async {
    final db = await _open();
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TransactionModel.fromMap(rows.single);
  }

  Future<FixedAssetModel?> fixedAssetById(int id) async {
    final db = await _open();
    final rows = await db.query('fixed_assets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : FixedAssetModel.fromMap(rows.single);
  }

  /// Tanggal terakhir yang sudah ditutup buku (null = belum pernah).
  Future<DateTime?> lockedUntil() async {
    final db = await _open();
    final v = (await db.rawQuery('SELECT MAX(closed_until) AS t FROM period_closings'))
        .first['t'] as String?;
    return v == null ? null : DateTime.parse(v);
  }

  /// Simpan transaksi (termasuk yang nantinya ditandai perlu_ditinjau), lalu
  /// perbarui kolom perlu_ditinjau seluruh baris.
  /// Lempar PeriodLockedException bila tanggalnya di periode terkunci.
  Future<int> insertTransaction(TransactionModel t) async {
    checkWrite(date: DateTime.parse(t.date), lockedUntil: await lockedUntil());
    final db = await _open();
    final id = await db.insert('transactions', _writable(t));
    await syncReviewFlags();
    return id;
  }

  /// Simpan hasil form. beli_aset_tetap: aset dan transaksinya dibuat dalam satu
  /// transaksi DB (gagal salah satu = tidak ada yang tersimpan).
  Future<int> insertDraft(TxDraft d) async {
    final asset = d.asset;
    if (asset == null) return insertTransaction(d.tx);
    checkWrite(date: DateTime.parse(d.tx.date), lockedUntil: await lockedUntil());
    final db = await _open();
    final id = await db.transaction((txn) async {
      final assetId = await txn.insert('fixed_assets', asset.toMap()..remove('id'));
      return txn.insert('transactions', _writable(d.tx)..['asset_id'] = assetId);
    });
    await syncReviewFlags();
    return id;
  }

  /// Ubah transaksi [d.tx.id]. Tanggal lama DAN baru harus di luar periode terkunci.
  /// Tipe, asset_id, dan rujukan retur tidak berubah lewat jalur ini.
  Future<void> updateDraft(TxDraft d) async {
    final old = await transactionById(d.tx.id!);
    if (old == null) throw StateError('transaksi #${d.tx.id} tidak ditemukan');
    checkEdit(
      oldDate: DateTime.parse(old.date),
      newDate: DateTime.parse(d.tx.date),
      lockedUntil: await lockedUntil(),
    );
    final db = await _open();
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        _writable(d.tx)
          ..['tx_type'] = old.txType.code
          ..['asset_id'] = old.assetId
          ..['reversal_of'] = old.reversalOf,
        where: 'id = ?',
        whereArgs: [old.id],
      );
      final asset = d.asset;
      if (asset != null && old.assetId != null) {
        await txn.update('fixed_assets', asset.toMap()..remove('id'),
            where: 'id = ?', whereArgs: [old.assetId]);
      }
    });
    await syncReviewFlags();
  }

  /// Lempar PeriodLockedException bila di periode terkunci; DatabaseException bila
  /// baris dirujuk retur/pelunasan lain. Aset tetap dari beli_aset_tetap ikut dihapus.
  Future<void> deleteTransaction(int id) async {
    final old = await transactionById(id);
    if (old == null) return;
    checkWrite(date: DateTime.parse(old.date), lockedUntil: await lockedUntil());
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      if (old.txType == TxType.beliAsetTetap && old.reversalOf == null && old.assetId != null) {
        await txn.delete('fixed_assets', where: 'id = ?', whereArgs: [old.assetId]);
      }
    });
    await syncReviewFlags();
  }

  /// Pilihan rujukan untuk form (piutang terbuka, transaksi yang bisa diretur).
  Future<({List<RefOption> piutang, List<RefOption> retur})> rujukan({int? kecuali}) async =>
      hitungRujukan(await transactions(), kecuali: kecuali);

  /// Laporan satu periode: Laba Rugi [from, asOf] (from null = sejak awal),
  /// Posisi Keuangan per asOf, ditambah ringkasan buku kas per asOf.
  /// `opening` = Posisi Keuangan sehari sebelum `from` (untuk saldo awal ekuitas).
  Future<PeriodReport> loadReport({required DateTime asOf, DateTime? from}) async {
    final input = buildEngineInput(await transactions(), await fixedAssets());
    return PeriodReport(
      from,
      asOf,
      buildReport(input.txs, input.assets, asOf: asOf, from: from),
      cashBookSummary(input.txs, asOf: asOf),
      opening: from == null
          ? null
          : buildReport(input.txs, input.assets,
              asOf: DateTime(from.year, from.month, from.day - 1)),
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
