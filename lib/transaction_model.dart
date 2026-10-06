// Baris tabel `transactions` skema v2. Uang = int Rupiah.
import 'accounting/engine.dart' show cashDirection;
import 'accounting/models.dart';

/// Sumber pembayaran untuk beban_operasional dan beli_aset_tetap.
enum PaymentSource { kas, utang }

T? _byName<T extends Enum>(List<T> values, Object? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('nilai enum tidak dikenal: $name');
}

TxType txTypeFromCode(String code) => TxType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => throw FormatException('tx_type tidak dikenal: $code'),
    );

class TransactionModel {
  final int? id;
  final TxType txType;
  final int amount;

  /// yyyy-MM-dd
  final String date;
  final int? qty;
  final StockItem? item;
  final ExpenseKind? expenseKind;
  final PaymentSource paymentSource;

  /// terima_piutang -> id penjualan_kredit.
  final int? refId;

  /// Retur/pembalik -> id transaksi asli.
  final int? reversalOf;

  /// beli_aset_tetap -> id fixed_assets.
  final int? assetId;

  /// Label rincian bebas (bukan penentu perhitungan).
  final String category;
  final String description;

  /// Cermin hasil mesin (lihat AccountingRepository.syncReviewFlags); bukan input.
  final bool perluDitinjau;
  final String? reviewNote;

  const TransactionModel({
    this.id,
    required this.txType,
    required this.amount,
    required this.date,
    this.qty,
    this.item,
    this.expenseKind,
    this.paymentSource = PaymentSource.kas,
    this.refId,
    this.reversalOf,
    this.assetId,
    this.category = '',
    this.description = '',
    this.perluDitinjau = false,
    this.reviewNote,
  });

  /// 1 kas masuk, -1 kas keluar, 0 tidak menyentuh kas (kredit, pemakaian stok, dll.).
  int get arahKas {
    final arah = cashDirection(txType, onCredit: paymentSource == PaymentSource.utang);
    return reversalOf == null ? arah : -arah;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'tx_type': txType.code,
        'amount': amount,
        'date': date,
        'qty': qty,
        'item': item?.name,
        'expense_kind': expenseKind?.name,
        'payment_source': paymentSource.name,
        'ref_id': refId,
        'reversal_of': reversalOf,
        'asset_id': assetId,
        'category': category,
        'description': description,
        'perlu_ditinjau': perluDitinjau ? 1 : 0,
        'review_note': reviewNote,
      };

  factory TransactionModel.fromMap(Map<String, Object?> m) => TransactionModel(
        id: m['id'] as int?,
        txType: txTypeFromCode(m['tx_type'] as String),
        amount: m['amount'] as int,
        date: m['date'] as String,
        qty: m['qty'] as int?,
        item: _byName(StockItem.values, m['item']),
        expenseKind: _byName(ExpenseKind.values, m['expense_kind']),
        paymentSource: _byName(PaymentSource.values, m['payment_source']) ?? PaymentSource.kas,
        refId: m['ref_id'] as int?,
        reversalOf: m['reversal_of'] as int?,
        assetId: m['asset_id'] as int?,
        category: (m['category'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        perluDitinjau: (m['perlu_ditinjau'] as int? ?? 0) == 1,
        reviewNote: m['review_note'] as String?,
      );

  /// Hanya baris yang sudah tersimpan (punya id) yang bisa dihitung mesin.
  AcctTx toAcctTx() => AcctTx(
        id: id!,
        date: DateTime.parse(date),
        type: txType,
        amount: amount,
        qty: qty,
        item: item,
        expense: expenseKind,
        onCredit: paymentSource == PaymentSource.utang,
        refId: refId,
        reversalOf: reversalOf,
        assetId: assetId,
      );
}

/// Baris tabel `fixed_assets`. Tidak menyimpan harga: harga perolehan = `amount`
/// transaksi beli_aset_tetap yang `asset_id`-nya menunjuk aset ini.
class FixedAssetModel {
  final int? id;
  final String name;

  /// yyyy-MM-dd; null = tanggal transaksi beli.
  final String? readyDate;

  /// null = tidak disusutkan (tanah).
  final int? lifeMonths;
  final String description;

  const FixedAssetModel({
    this.id,
    required this.name,
    this.readyDate,
    this.lifeMonths,
    this.description = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'ready_date': readyDate,
        'life_months': lifeMonths,
        'description': description,
      };

  factory FixedAssetModel.fromMap(Map<String, Object?> m) => FixedAssetModel(
        id: m['id'] as int?,
        name: m['name'] as String,
        readyDate: m['ready_date'] as String?,
        lifeMonths: m['life_months'] as int?,
        description: (m['description'] as String?) ?? '',
      );
}
