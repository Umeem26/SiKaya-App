// Satu sumber kebenaran angka keuangan: baris DB -> TransactionModel -> mesin.
// Dashboard, daftar keuangan, dan halaman laporan membaca dari sini.
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../transaction_model.dart';
import 'calk.dart';
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

/// Ringkasan periode yang akan ditutup buku (dipakai dialog konfirmasi dan closeBook).
class ClosingPreview {
  /// Hari sesudah tutup buku sebelumnya; null = sejak awal pencatatan.
  final DateTime? from;
  final DateTime until;

  /// Laba Rugi [from, until] dan Posisi Keuangan per until.
  final Report report;
  const ClosingPreview(this.from, this.until, this.report);
}

class ClosingResult {
  final ClosingPreview preview;
  final String backupPath;
  final int closingTxId;
  const ClosingResult(this.preview, this.backupPath, this.closingTxId);
}

/// Tutup buku ditolak (periode sudah ditutup, tanggal di masa depan, data perlu ditinjau).
class ClosingRejectedException implements Exception {
  ClosingRejectedException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

DateTime _hari(DateTime t) => DateTime(t.year, t.month, t.day);
String _iso(DateTime t) => t.toIso8601String().substring(0, 10);

class AccountingRepository {
  AccountingRepository(this._open, {Future<String> Function()? backup}) : _backup = backup;

  final Future<Database> Function() _open;

  /// Menyalin file DB sebelum tutup buku; mengembalikan path cadangan.
  final Future<String> Function()? _backup;

  static final AccountingRepository instance = AccountingRepository(
    () => DatabaseHelper.instance.database,
    backup: () => DatabaseHelper.instance.backup('tutupbuku'),
  );

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

  /// CaLK periode yang sama dengan [loadReport].
  Future<List<CalkSection>> loadCalk({
    required DateTime asOf,
    DateTime? from,
    String namaUsaha = 'Usaha peternakan',
  }) async {
    final input = buildEngineInput(await transactions(), await fixedAssets());
    return buildCalk(
      txs: input.txs,
      assets: input.assets,
      report: buildReport(input.txs, input.assets, asOf: asOf, from: from),
      asOf: asOf,
      from: from,
      lockedUntil: await lockedUntil(),
      namaUsaha: namaUsaha,
    );
  }

  /// Periksa apakah periode s.d. [until] boleh ditutup, dan hitung labanya lewat mesin.
  Future<ClosingPreview> previewClosing(DateTime until, {DateTime? today}) async {
    until = _hari(until);
    final lock = await lockedUntil();
    if (lock != null && !until.isAfter(lock)) {
      throw ClosingRejectedException('Periode sampai ${_iso(lock)} sudah ditutup buku. '
          'Tutup buku berikutnya harus bertanggal sesudah ${_iso(lock)}.');
    }
    if (until.isAfter(_hari(today ?? DateTime.now()))) {
      throw ClosingRejectedException('Tanggal tutup buku tidak boleh sesudah hari ini.');
    }
    final from = lock == null ? null : DateTime(lock.year, lock.month, lock.day + 1);
    final input = buildEngineInput(await transactions(), await fixedAssets());
    final r = buildReport(input.txs, input.assets, asOf: until, from: from);
    if (r.perluDitinjau.isNotEmpty) {
      throw ClosingRejectedException('${r.peringatanTinjau!.jumlahTransaksi} transaksi sampai '
          '${_iso(until)} masih perlu ditinjau. Ubah atau hapus dulu, karena sesudah '
          'tutup buku transaksi itu terkunci.');
    }
    if (!r.balanced) {
      throw ClosingRejectedException('Laporan per ${_iso(until)} tidak seimbang; tutup buku dibatalkan.');
    }
    return ClosingPreview(from, until, r);
  }

  /// Tutup buku non-destruktif: backup file DB, catat entri tutup_buku (laba periode)
  /// ke Saldo Laba, simpan period_closings, kunci periode. Tidak ada transaksi dihapus.
  Future<ClosingResult> closeBook(DateTime until, {DateTime? today}) async {
    final backup = _backup;
    if (backup == null) throw StateError('tutup buku butuh fungsi backup');
    final p = await previewClosing(until, today: today);
    final backupPath = await backup();
    final assets = await fixedAssets();
    final db = await _open();
    final txId = await db.transaction((txn) async {
      final entri = buildClosingEntry(p.report, id: 0, date: p.until);
      final id = await txn.insert('transactions', {
        'tx_type': entri.type.code,
        'amount': entri.amount,
        'date': _iso(p.until),
        'category': 'Tutup Buku',
        'description': 'Laba (rugi) periode ${p.from == null ? 'awal' : _iso(p.from!)} '
            's.d. ${_iso(p.until)} dicatat ke Saldo Laba',
      });
      // D5 sebelum commit: total aset dan saldo laba tidak berubah.
      final rows = (await txn.query('transactions')).map(TransactionModel.fromMap).toList();
      final input = buildEngineInput(rows, assets);
      final after = buildReport(input.txs, input.assets, asOf: p.until, from: p.from);
      if (after.totalAset != p.report.totalAset ||
          after.saldoLaba != p.report.saldoLaba ||
          after.perluDitinjau.isNotEmpty) {
        throw StateError('tutup buku mengubah total aset/saldo laba; dibatalkan');
      }
      await txn.insert('period_closings', {
        'closed_until': _iso(p.until),
        'closing_tx_id': id,
        'laba_bersih': p.report.labaBersih,
        'total_aset': p.report.totalAset,
        'saldo_laba': p.report.saldoLaba,
        'created_at': DateTime.now().toIso8601String(),
      });
      return id;
    });
    return ClosingResult(p, backupPath, txId);
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
