// Konfigurasi form input per tipe transaksi (Fase 1, bagian A).
// SATU tabel (txFormSpecs + returFormSpec) menentukan field, label, wajib/opsional,
// dan validasi. Tampilan (form_finance_page.dart) hanya merender tabel ini, sehingga
// Fase 3 bisa mengganti tampilan tanpa menyentuh logika. Tanpa Flutter: bisa dites.
import 'package:intl/intl.dart';

import '../transaction_model.dart';
import 'models.dart';

enum FieldKind { tanggal, uang, jumlah, teks, pilihan, rujukan }

enum FieldKey {
  /// terima_piutang -> id penjualan_kredit yang masih punya sisa.
  rujukanPiutang(FieldKind.rujukan),

  /// Retur -> id transaksi asal yang masih bisa diretur.
  transaksiAsal(FieldKind.rujukan),
  item(FieldKind.pilihan),
  jenisBeban(FieldKind.pilihan),
  namaAset(FieldKind.teks),
  tanggal(FieldKind.tanggal),
  qty(FieldKind.jumlah),
  nominal(FieldKind.uang),
  sumberBayar(FieldKind.pilihan),
  tanggalSiapPakai(FieldKind.tanggal),
  umurBulan(FieldKind.jumlah),
  keterangan(FieldKind.teks);

  const FieldKey(this.kind);
  final FieldKind kind;
}

class Pilihan {
  const Pilihan(this.value, this.label);
  final Object value;
  final String label;
}

/// Transaksi yang bisa dirujuk (penjualan kredit terbuka / asal retur) beserta sisanya.
class RefOption {
  const RefOption({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.sisa,
    required this.label,
  });
  final int id;
  final TxType type;

  /// yyyy-MM-dd
  final String date;
  final int amount;
  final int sisa;
  final String label;
}

/// Nilai form yang sedang diisi + data rujukan untuk validasi lintas field.
class FormInput {
  FormInput(this.values, {this.rujukan = const {}});
  final Map<FieldKey, Object?> values;
  final Map<int, RefOption> rujukan;
  Object? operator [](FieldKey k) => values[k];

  RefOption? get refTerpilih {
    final id = values[FieldKey.rujukanPiutang] ?? values[FieldKey.transaksiAsal];
    return id is int ? rujukan[id] : null;
  }
}

typedef Validator = String? Function(Object? nilai, FormInput input);

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.wajib = true,
    this.hint,
    this.pilihan = const [],
    this.validasi = const [],
  });
  final FieldKey key;
  final String label;
  final bool wajib;
  final String? hint;

  /// Pilihan tetap untuk FieldKind.pilihan. Rujukan diisi dari data (FormInput.rujukan).
  final List<Pilihan> pilihan;

  /// Dijalankan berurutan bila field terisi; pesan pertama yang bukan null dipakai.
  final List<Validator> validasi;
}

class TxTypeFormSpec {
  const TxTypeFormSpec({
    required this.type,
    required this.label,
    this.penjelasan,
    this.fields = const [],
    this.otomatis,
    this.itemTetap,
  });

  /// null hanya untuk retur: tipe mengikuti transaksi asal.
  final TxType? type;

  /// Nama dalam bahasa petani (layar "Apa yang terjadi?").
  final String label;
  final String? penjelasan;
  final List<FieldSpec> fields;

  /// Bukan null = tidak bisa diinput manual; teks ini alasannya.
  final String? otomatis;

  /// Item stok yang selalu dipakai tipe ini (kematian_ternak -> ternak).
  final StockItem? itemTetap;

  bool get manual => otomatis == null;
  bool get retur => type == null;
  FieldSpec? field(FieldKey k) => fields.where((f) => f.key == k).firstOrNull;
}

/// Hasil form: satu transaksi, plus aset tetap baru untuk beli_aset_tetap.
class TxDraft {
  const TxDraft(this.tx, {this.asset});
  final TransactionModel tx;
  final FixedAssetModel? asset;
}

class FormInvalidException implements Exception {
  FormInvalidException(this.errors);
  final Map<FieldKey, String> errors;
  @override
  String toString() => 'Form tidak valid: $errors';
}

// --- Validator ---

final _fmtTanggal = DateFormat('yyyy-MM-dd');

DateTime? parseTanggal(Object? v) {
  if (v is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return null;
  final t = DateTime.tryParse(v);
  return t != null && _fmtTanggal.format(t) == v ? t : null;
}

String? _tanggalSah(Object? v, FormInput _) =>
    parseTanggal(v) == null ? 'Tanggal tidak sah (yyyy-MM-dd)' : null;

String? _bulatPositif(Object? v, FormInput _) =>
    v is int && v > 0 ? null : 'Harus bilangan bulat lebih dari 0';

String? _umurWajar(Object? v, FormInput _) =>
    v is int && v > 1200 ? 'Umur manfaat paling lama 1200 bulan' : null;

String? _rujukanAda(Object? v, FormInput input) =>
    v is int && input.rujukan.containsKey(v) ? null : 'Pilih transaksi dari daftar';

String? _tidakMelebihiSisa(Object? v, FormInput input) {
  final ref = input.refTerpilih;
  if (ref == null || v is! int || v <= ref.sisa) return null;
  return 'Melebihi sisa ${formatRupiah(ref.sisa)}';
}

String? _tidakSebelumRujukan(Object? v, FormInput input) {
  final ref = input.refTerpilih, t = parseTanggal(v);
  if (ref == null || t == null || !t.isBefore(DateTime.parse(ref.date))) return null;
  return 'Tidak boleh sebelum tanggal transaksi asal (${ref.date})';
}

String? _tidakSebelumBeli(Object? v, FormInput input) {
  final siap = parseTanggal(v), beli = parseTanggal(input[FieldKey.tanggal]);
  if (siap == null || beli == null || !siap.isBefore(beli)) return null;
  return 'Tidak boleh sebelum tanggal beli';
}

String formatRupiah(int v) =>
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(v);

// --- Field bersama ---

const _tanggal = FieldSpec(FieldKey.tanggal, 'Tanggal', validasi: [_tanggalSah]);
const _nominal = FieldSpec(FieldKey.nominal, 'Nominal (Rp)', validasi: [_bulatPositif]);
const _keterangan = FieldSpec(FieldKey.keterangan, 'Catatan', wajib: false, hint: 'Opsional');
const _qty = FieldSpec(FieldKey.qty, 'Jumlah (kg / dosis / ekor)', validasi: [_bulatPositif]);

const _item = FieldSpec(FieldKey.item, 'Barang', pilihan: [
  Pilihan(StockItem.pakan, 'Pakan'),
  Pilihan(StockItem.obat, 'Obat & vitamin'),
  Pilihan(StockItem.ternak, 'Ternak / bibit (DOC)'),
]);

const _sumberBayar = FieldSpec(FieldKey.sumberBayar, 'Cara bayar', pilihan: [
  Pilihan(PaymentSource.kas, 'Tunai (kas)'),
  Pilihan(PaymentSource.utang, 'Utang (bayar nanti)'),
]);

/// Sama dengan `_bisaDibalik` di engine.dart: tipe tanpa efek stok/aset tetap.
const tipeBisaDiretur = {
  TxType.penjualanTunai,
  TxType.penjualanKredit,
  TxType.terimaPiutang,
  TxType.bebanOperasional,
  TxType.bebanBunga,
  TxType.setorModal,
  TxType.prive,
  TxType.terimaPinjaman,
  TxType.bayarCicilanPokok,
};

// --- TABEL KONFIGURASI ---

/// Satu spec per TxType (16), urutan = urutan di layar "Apa yang terjadi?".
const Map<TxType, TxTypeFormSpec> txFormSpecs = {
  TxType.penjualanTunai: TxTypeFormSpec(
    type: TxType.penjualanTunai,
    label: 'Jual, dibayar tunai',
    penjelasan: 'Hasil ternak/panen terjual dan uangnya sudah diterima',
    fields: [_tanggal, _nominal, _keterangan],
  ),
  TxType.penjualanKredit: TxTypeFormSpec(
    type: TxType.penjualanKredit,
    label: 'Jual, belum dibayar (piutang)',
    penjelasan: 'Barang sudah diserahkan, pembeli bayar nanti',
    fields: [_tanggal, _nominal, FieldSpec(FieldKey.keterangan, 'Nama pembeli / catatan', wajib: false)],
  ),
  TxType.terimaPiutang: TxTypeFormSpec(
    type: TxType.terimaPiutang,
    label: 'Terima pembayaran piutang',
    penjelasan: 'Pembeli membayar penjualan yang dulu belum dibayar (boleh sebagian)',
    fields: [
      FieldSpec(FieldKey.rujukanPiutang, 'Penjualan yang dibayar', validasi: [_rujukanAda]),
      FieldSpec(FieldKey.tanggal, 'Tanggal', validasi: [_tanggalSah, _tidakSebelumRujukan]),
      FieldSpec(FieldKey.nominal, 'Nominal diterima (Rp)', validasi: [_bulatPositif, _tidakMelebihiSisa]),
      _keterangan,
    ],
  ),
  TxType.beliPersediaanTunai: TxTypeFormSpec(
    type: TxType.beliPersediaanTunai,
    label: 'Beli pakan/obat/bibit, bayar tunai',
    fields: [
      _tanggal,
      _item,
      _qty,
      FieldSpec(FieldKey.nominal, 'Total harga (Rp)', validasi: [_bulatPositif]),
      _keterangan,
    ],
  ),
  TxType.beliPersediaanKredit: TxTypeFormSpec(
    type: TxType.beliPersediaanKredit,
    label: 'Beli pakan/obat/bibit, utang',
    fields: [
      _tanggal,
      _item,
      _qty,
      FieldSpec(FieldKey.nominal, 'Total harga (Rp)', validasi: [_bulatPositif]),
      FieldSpec(FieldKey.keterangan, 'Nama penjual / catatan', wajib: false),
    ],
  ),
  TxType.pakaiPersediaan: TxTypeFormSpec(
    type: TxType.pakaiPersediaan,
    label: 'Pakai stok / ternak keluar karena dijual',
    penjelasan: 'Pakan atau obat dipakai, atau ternak keluar kandang karena terjual. '
        'Nilainya dihitung otomatis dari harga rata-rata stok.',
    fields: [_tanggal, _item, _qty, _keterangan],
  ),
  TxType.bebanOperasional: TxTypeFormSpec(
    type: TxType.bebanOperasional,
    label: 'Bayar biaya operasional',
    penjelasan: 'Listrik, air, upah, perawatan kandang, dan biaya lain',
    fields: [
      _tanggal,
      FieldSpec(FieldKey.jenisBeban, 'Jenis biaya', pilihan: [
        Pilihan(ExpenseKind.listrikAir, 'Listrik & air'),
        Pilihan(ExpenseKind.tenagaKerja, 'Upah tenaga kerja'),
        Pilihan(ExpenseKind.perawatan, 'Perawatan kandang'),
        Pilihan(ExpenseKind.lain, 'Lain-lain'),
      ]),
      _nominal,
      _sumberBayar,
      _keterangan,
    ],
  ),
  TxType.beliAsetTetap: TxTypeFormSpec(
    type: TxType.beliAsetTetap,
    label: 'Beli kandang/peralatan/kendaraan',
    penjelasan: 'Barang tahan lama; nilainya disusutkan otomatis setiap bulan',
    fields: [
      FieldSpec(FieldKey.namaAset, 'Nama aset'),
      _tanggal,
      FieldSpec(FieldKey.nominal, 'Harga beli (Rp)', validasi: [_bulatPositif]),
      _sumberBayar,
      FieldSpec(FieldKey.tanggalSiapPakai, 'Tanggal mulai dipakai',
          wajib: false, hint: 'Kosong = sama dengan tanggal beli', validasi: [_tanggalSah, _tidakSebelumBeli]),
      FieldSpec(FieldKey.umurBulan, 'Umur manfaat (bulan)',
          hint: 'Mis. peralatan kecil 48, kandang semi permanen 120, kendaraan 96',
          validasi: [_bulatPositif, _umurWajar]),
      _keterangan,
    ],
  ),
  TxType.penyusutan: TxTypeFormSpec(
    type: TxType.penyusutan,
    label: 'Penyusutan aset',
    otomatis: 'Dihitung otomatis dari aset tetap setiap bulan, tidak dicatat manual.',
  ),
  TxType.setorModal: TxTypeFormSpec(
    type: TxType.setorModal,
    label: 'Masukkan uang pribadi ke usaha (modal)',
    fields: [_tanggal, _nominal, _keterangan],
  ),
  TxType.prive: TxTypeFormSpec(
    type: TxType.prive,
    label: 'Ambil uang usaha untuk keperluan pribadi',
    fields: [_tanggal, _nominal, _keterangan],
  ),
  TxType.terimaPinjaman: TxTypeFormSpec(
    type: TxType.terimaPinjaman,
    label: 'Terima pinjaman',
    fields: [_tanggal, _nominal, FieldSpec(FieldKey.keterangan, 'Pemberi pinjaman / catatan', wajib: false)],
  ),
  TxType.bayarCicilanPokok: TxTypeFormSpec(
    type: TxType.bayarCicilanPokok,
    label: 'Bayar cicilan pokok pinjaman',
    penjelasan: 'Hanya bagian pokok; bunga dicatat terpisah',
    fields: [_tanggal, _nominal, _keterangan],
  ),
  TxType.bebanBunga: TxTypeFormSpec(
    type: TxType.bebanBunga,
    label: 'Bayar bunga pinjaman',
    fields: [_tanggal, _nominal, _keterangan],
  ),
  TxType.tutupBuku: TxTypeFormSpec(
    type: TxType.tutupBuku,
    label: 'Tutup buku',
    otomatis: 'Dibuat lewat menu Pengaturan > Tutup Buku.',
  ),
  TxType.kematianTernak: TxTypeFormSpec(
    type: TxType.kematianTernak,
    label: 'Ternak mati',
    penjelasan: 'Kerugian dihitung otomatis dari harga rata-rata ternak',
    itemTetap: StockItem.ternak,
    fields: [
      _tanggal,
      FieldSpec(FieldKey.qty, 'Jumlah ekor mati', validasi: [_bulatPositif]),
      _keterangan,
    ],
  ),
};

/// Retur / pembatalan sebagian: transaksi pembalik (tipe = tipe asal, reversalOf = id asal).
const returFormSpec = TxTypeFormSpec(
  type: null,
  label: 'Retur / batalkan sebagian transaksi',
  penjelasan: 'Juga dipakai untuk mengoreksi transaksi di periode yang sudah ditutup buku',
  fields: [
    FieldSpec(FieldKey.transaksiAsal, 'Transaksi asal', validasi: [_rujukanAda]),
    FieldSpec(FieldKey.tanggal, 'Tanggal', validasi: [_tanggalSah, _tidakSebelumRujukan]),
    FieldSpec(FieldKey.nominal, 'Nominal retur (Rp)', validasi: [_bulatPositif, _tidakMelebihiSisa]),
    _keterangan,
  ],
);

TxTypeFormSpec specFor(TransactionModel t) =>
    t.reversalOf != null ? returFormSpec : txFormSpecs[t.txType]!;

String labelTransaksi(TransactionModel t) => t.category.isNotEmpty
    ? t.category
    : (t.reversalOf != null ? 'Retur ' : '') + txFormSpecs[t.txType]!.label;

bool _kosong(Object? v) => v == null || (v is String && v.trim().isEmpty);

/// Pesan galat per field (kosong = valid).
Map<FieldKey, String> validateForm(TxTypeFormSpec spec, FormInput input) {
  final errors = <FieldKey, String>{};
  if (!spec.manual) return {FieldKey.keterangan: spec.otomatis!};
  for (final f in spec.fields) {
    final v = input[f.key];
    if (_kosong(v)) {
      if (f.wajib) errors[f.key] = '${f.label} wajib diisi';
      continue;
    }
    if (f.key.kind == FieldKind.pilihan &&
        f.pilihan.isNotEmpty &&
        !f.pilihan.any((p) => p.value == v)) {
      errors[f.key] = 'Pilihan tidak dikenal';
      continue;
    }
    for (final cek in f.validasi) {
      final pesan = cek(v, input);
      if (pesan != null) {
        errors[f.key] = pesan;
        break;
      }
    }
  }
  return errors;
}

/// Ubah isi form menjadi transaksi (+ aset tetap). Lempar FormInvalidException bila tidak valid.
/// [id] diisi saat mengubah transaksi yang sudah ada.
TxDraft buildDraft(TxTypeFormSpec spec, FormInput input, {int? id}) {
  final errors = validateForm(spec, input);
  if (errors.isNotEmpty) throw FormInvalidException(errors);
  Object? v(FieldKey k) => _kosong(input[k]) ? null : input[k];

  final asal = spec.retur ? input.rujukan[v(FieldKey.transaksiAsal)]! : null;
  final type = spec.type ?? asal!.type;
  final tx = TransactionModel(
    id: id,
    txType: type,
    amount: v(FieldKey.nominal) as int? ?? 0,
    date: v(FieldKey.tanggal) as String,
    qty: v(FieldKey.qty) as int?,
    item: v(FieldKey.item) as StockItem? ?? spec.itemTetap,
    expenseKind: v(FieldKey.jenisBeban) as ExpenseKind?,
    paymentSource: v(FieldKey.sumberBayar) as PaymentSource? ?? PaymentSource.kas,
    refId: v(FieldKey.rujukanPiutang) as int?,
    reversalOf: asal?.id,
    category: asal != null ? 'Retur: ${txFormSpecs[type]!.label}' : spec.label,
    description: (v(FieldKey.keterangan) as String?)?.trim() ?? '',
  );
  final asset = spec.field(FieldKey.namaAset) == null
      ? null
      : FixedAssetModel(
          name: (v(FieldKey.namaAset) as String).trim(),
          readyDate: v(FieldKey.tanggalSiapPakai) as String?,
          lifeMonths: v(FieldKey.umurBulan) as int?,
        );
  return TxDraft(tx, asset: asset);
}

/// Isi form dari transaksi tersimpan (mode ubah).
Map<FieldKey, Object?> valuesFrom(TransactionModel t, {FixedAssetModel? asset}) => {
      FieldKey.tanggal: t.date,
      FieldKey.nominal: t.amount,
      FieldKey.qty: t.qty,
      FieldKey.item: t.item,
      FieldKey.jenisBeban: t.expenseKind,
      FieldKey.sumberBayar: t.paymentSource,
      FieldKey.rujukanPiutang: t.refId,
      FieldKey.transaksiAsal: t.reversalOf,
      FieldKey.keterangan: t.description,
      if (asset != null) ...{
        FieldKey.namaAset: asset.name,
        FieldKey.tanggalSiapPakai: asset.readyDate,
        FieldKey.umurBulan: asset.lifeMonths,
      },
    };

/// Penjualan kredit dengan sisa piutang > 0 dan transaksi yang masih bisa diretur.
/// Hanya baris yang tidak perlu_ditinjau (cermin mesin). [kecuali] = baris yang sedang
/// diubah, tidak ikut mengurangi sisa.
({List<RefOption> piutang, List<RefOption> retur}) hitungRujukan(
  List<TransactionModel> rows, {
  int? kecuali,
}) {
  final valid = rows.where((r) => !r.perluDitinjau && r.id != kecuali).toList();
  final diretur = <int, int>{};
  for (final r in valid.where((r) => r.reversalOf != null)) {
    diretur[r.reversalOf!] = (diretur[r.reversalOf!] ?? 0) + r.amount;
  }
  final dibayar = <int, int>{};
  for (final r in valid.where((r) => r.txType == TxType.terimaPiutang && r.reversalOf == null)) {
    if (r.refId == null) continue;
    dibayar[r.refId!] = (dibayar[r.refId!] ?? 0) + r.amount - (diretur[r.id] ?? 0);
  }
  RefOption opt(TransactionModel r, int sisa) => RefOption(
        id: r.id!,
        type: r.txType,
        date: r.date,
        amount: r.amount,
        sisa: sisa,
        label: '#${r.id} ${r.date} ${labelTransaksi(r)} ${formatRupiah(r.amount)}',
      );
  final asli = valid.where((r) => r.reversalOf == null && tipeBisaDiretur.contains(r.txType));
  final piutang = <RefOption>[], retur = <RefOption>[];
  for (final r in asli) {
    final kredit = r.txType == TxType.penjualanKredit;
    final sisa = r.amount - (diretur[r.id] ?? 0) - (kredit ? dibayar[r.id] ?? 0 : 0);
    if (sisa <= 0) continue;
    retur.add(opt(r, sisa));
    if (kredit) piutang.add(opt(r, sisa));
  }
  return (piutang: piutang, retur: retur);
}

/// Pesan untuk pengguna saat menulis ke periode yang sudah ditutup buku.
String pesanPeriodeTerkunci(PeriodLockedException e) {
  final kunci = _fmtTanggal.format(e.lockedUntil);
  return 'Periode sampai $kunci sudah ditutup buku, jadi transaksi bertanggal '
      '${_fmtTanggal.format(e.date)} tidak bisa ditambah, diubah, atau dihapus. '
      'Untuk koreksi, catat retur/transaksi pembalik bertanggal sesudah $kunci.';
}
