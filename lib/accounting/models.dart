// Model akuntansi SAK EMKM (Fase 1, tahap 1: KERANGKA).
// Semua uang = bilangan bulat Rupiah (int). Lihat PLAN-FASE1.md.

/// 16 tipe transaksi: 15 dari ACCOUNTING-SPEC bagian C + kematianTernak (kasus tepi B7).
enum TxType {
  penjualanTunai('penjualan_tunai'),
  penjualanKredit('penjualan_kredit'),
  terimaPiutang('terima_piutang'),
  beliPersediaanTunai('beli_persediaan_tunai'),
  beliPersediaanKredit('beli_persediaan_kredit'),
  pakaiPersediaan('pakai_persediaan'),
  bebanOperasional('beban_operasional'),
  beliAsetTetap('beli_aset_tetap'),
  penyusutan('penyusutan'),
  setorModal('setor_modal'),
  prive('prive'),
  terimaPinjaman('terima_pinjaman'),
  bayarCicilanPokok('bayar_cicilan_pokok'),
  bebanBunga('beban_bunga'),
  tutupBuku('tutup_buku'),
  kematianTernak('kematian_ternak');

  const TxType(this.code);
  final String code;
}

enum StockItem { pakan, obat, ternak }

enum ExpenseKind {
  pakan,
  obat,
  bpp,
  listrikAir,
  tenagaKerja,
  perawatan,
  penyusutan,
  bunga,
  kerugianTernak,
  lain,
}

enum ReviewReason {
  pemakaianMelebihiStok,
  pelunasanMelebihiPiutang,
  returMelebihiAsli,
  referensiTidakDitemukan,

  /// Data tidak lengkap/tidak sah (nilai negatif, item/qty kosong, entri penyusutan manual, dll.).
  dataTidakValid,
}

/// Satu transaksi buku. Urutan pemrosesan = `id` naik (bukan urutan list, bukan tanggal saja).
class AcctTx {
  final int id;
  final DateTime date;
  final TxType type;

  /// Rupiah bulat. Untuk pakaiPersediaan dan kematianTernak nilai ini DIABAIKAN
  /// (dihitung mesin dari rata-rata tertimbang).
  final int amount;
  final int? qty;
  final StockItem? item;

  /// Untuk bebanOperasional.
  final ExpenseKind? expense;

  /// Untuk bebanOperasional dan beliAsetTetap: true = dibayar dengan utang.
  final bool onCredit;

  /// terimaPiutang -> id penjualanKredit yang dilunasi.
  final int? refId;

  /// Transaksi pembalik (retur): id transaksi asli. Efeknya meniadakan `amount` dari yang asli.
  final int? reversalOf;

  /// beliAsetTetap -> id FixedAsset.
  final int? assetId;

  const AcctTx({
    required this.id,
    required this.date,
    required this.type,
    this.amount = 0,
    this.qty,
    this.item,
    this.expense,
    this.onCredit = false,
    this.refId,
    this.reversalOf,
    this.assetId,
  });
}

class FixedAsset {
  final int id;
  final String name;
  final int cost;

  /// Tanggal siap dipakai (default = tanggal beli). Bulan ini disusutkan penuh.
  final DateTime readyDate;

  /// null = tidak disusutkan (tanah).
  final int? lifeMonths;

  const FixedAsset({
    required this.id,
    required this.name,
    required this.cost,
    required this.readyDate,
    this.lifeMonths,
  });
}

class ReviewFlag {
  final int txId;
  final ReviewReason reason;
  final String detail;

  /// Nilai Rupiah transaksi yang dikeluarkan. Untuk pemakaian melebihi stok:
  /// taksiran qty diminta x biaya rata-rata saat itu (0 bila stok kosong).
  final int nilai;
  const ReviewFlag(this.txId, this.reason, this.detail, {this.nilai = 0});
}

/// Ringkasan transaksi perlu_ditinjau yang TIDAK dihitung di laporan.
class ReviewWarning {
  final int jumlahTransaksi;
  final int totalNilai;
  const ReviewWarning(this.jumlahTransaksi, this.totalNilai);

  String get pesan => '$jumlahTransaksi transaksi perlu ditinjau '
      '(total nilai Rp${_rupiah(totalNilai)}) dan tidak dihitung dalam laporan.';
}

String _rupiah(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class Report {
  // Laporan Posisi Keuangan (per asOf)
  final int kas;
  final int piutang;
  final Map<StockItem, int> persediaan;
  final int asetTetapBruto;
  final int akumulasiPenyusutan;
  final int totalAset;
  final int utang;
  final int modalDisetor;
  final int prive; // kumulatif
  final int saldoLaba; // laba kumulatif - prive kumulatif
  final int totalLiabilitasEkuitas;
  final bool balanced;

  // Laporan Laba Rugi (periode from..asOf; from null = sejak awal)
  final int pendapatan;
  final Map<ExpenseKind, int> beban;
  final int bebanTotal;
  final int labaBersih;

  /// Baris yang dikeluarkan dari laporan dan perlu keputusan pemilik.
  final List<ReviewFlag> perluDitinjau;

  const Report({
    required this.kas,
    required this.piutang,
    required this.persediaan,
    required this.asetTetapBruto,
    required this.akumulasiPenyusutan,
    required this.totalAset,
    required this.utang,
    required this.modalDisetor,
    required this.prive,
    required this.saldoLaba,
    required this.totalLiabilitasEkuitas,
    required this.balanced,
    required this.pendapatan,
    required this.beban,
    required this.bebanTotal,
    required this.labaBersih,
    required this.perluDitinjau,
  });

  int get asetTetapNeto => asetTetapBruto - akumulasiPenyusutan;
  int get persediaanTotal => persediaan.values.fold(0, (a, b) => a + b);

  /// null bila tidak ada transaksi perlu_ditinjau.
  ReviewWarning? get peringatanTinjau => perluDitinjau.isEmpty
      ? null
      : ReviewWarning(perluDitinjau.map((f) => f.txId).toSet().length,
          perluDitinjau.fold(0, (a, f) => a + f.nilai));
}

/// Ringkasan buku kas: total masuk, total keluar, saldo.
class CashSummary {
  final int masuk;
  final int keluar;
  const CashSummary(this.masuk, this.keluar);
  int get saldo => masuk - keluar;
}

class PeriodLockedException implements Exception {
  final DateTime date;
  final DateTime lockedUntil;
  PeriodLockedException(this.date, this.lockedUntil);
  @override
  String toString() => 'Periode terkunci sampai $lockedUntil; tanggal $date ditolak.';
}
