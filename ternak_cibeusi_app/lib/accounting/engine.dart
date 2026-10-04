// Mesin laporan akuntansi SAK EMKM (Fase 1). Fungsi murni: tanpa SQLite.
// Semua uang = int Rupiah, tanpa double. Logika lama
// (lib/database/database_helper.dart) tidak diubah.
import 'models.dart';

/// num/den dibulatkan setengah menjauhi nol (simetris) dengan aritmetika bilangan
/// bulat: 0,5 -> 1; 1,5 -> 2; -0,5 -> -1; -1,5 -> -2; -1,4 -> -1.
/// Sifat: f(-n, d) == -f(n, d), sehingga transaksi dan pembaliknya saling meniadakan.
/// Dipakai untuk rata-rata tertimbang dan penyusutan. `den` harus positif.
int roundHalfAwayFromZero(int num, int den) {
  if (den <= 0) throw ArgumentError.value(den, 'den', 'harus positif');
  final q = (2 * num.abs() + den) ~/ (2 * den);
  return num < 0 ? -q : q;
}

int _day(DateTime t) => t.year * 10000 + t.month * 100 + t.day;
int _month(DateTime t) => t.year * 12 + t.month - 1;
DateTime _dayBefore(DateTime t) => DateTime(t.year, t.month, t.day - 1);

/// Susutan per bulan: bulan 0..life-1; bulan terakhir mengambil sisa pembulatan.
/// Jumlah seluruh elemen == cost. Susutan bulanan = roundHalfAwayFromZero(cost, life),
/// berhenti (0) saat akumulasi sudah == cost.
List<int> depreciationSchedule(FixedAsset asset) {
  final life = asset.lifeMonths;
  if (life == null || life <= 0) return const [];
  final perBulan = roundHalfAwayFromZero(asset.cost, life);
  final s = <int>[];
  var sisa = asset.cost;
  for (var i = 0; i < life - 1; i++) {
    final x = perBulan < sisa ? perBulan : sisa;
    s.add(x);
    sisa -= x;
  }
  s.add(sisa);
  return s;
}

/// Akumulasi penyusutan sampai bulan `asOf` (bulan penuh, bulan siap-pakai dihitung).
/// Berhenti saat akumulasi == cost. Tanah (lifeMonths null) = 0.
int accumulatedDepreciation(FixedAsset asset, DateTime asOf) {
  if (_day(asOf) < _day(asset.readyDate)) return 0;
  final bulan = _month(asOf) - _month(asset.readyDate) + 1;
  return depreciationSchedule(asset).take(bulan).fold<int>(0, (a, b) => a + b);
}

/// Tipe yang boleh dibalik (retur) di Fase 1: tanpa efek stok/aset tetap.
const _bisaDibalik = {
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

/// Validasi + rata-rata tertimbang, dipakai bersama buildReport dan cashBookBalance.
/// Transaksi tidak valid disimpan sebagai ReviewFlag dan dikeluarkan dari `valid`.
class _Book {
  final valid = <AcctTx>[];
  final flags = <ReviewFlag>[];

  /// id transaksi asli (bukan retur) yang valid.
  final byId = <int, AcctTx>{};

  /// id pakai/kematian -> biaya rata-rata tertimbang.
  final biayaPakai = <int, int>{};

  final _dibalik = <int, int>{}; // id asli -> total retur
  final _sisaPiutang = <int, int>{}; // id penjualan kredit -> sisa
  final _asetDibeli = <int>{};
  final _qty = {for (final i in StockItem.values) i: 0};
  final _nilai = {for (final i in StockItem.values) i: 0};

  _Book(List<AcctTx> txs, DateTime asOf) {
    final batas = _day(asOf);
    final urut = txs.where((t) => _day(t.date) <= batas).toList()
      ..sort((a, b) {
        final c = _day(a.date).compareTo(_day(b.date));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    for (final t in urut) {
      final f = t.reversalOf == null ? _terima(t) : _terimaRetur(t);
      if (f != null) {
        flags.add(f);
      } else {
        valid.add(t);
        if (t.reversalOf == null) byId[t.id] = t;
      }
    }
  }

  AcctTx asli(AcctTx t) => t.reversalOf == null ? t : byId[t.reversalOf]!;

  ReviewFlag? _terima(AcctTx t) {
    ReviewFlag tidakValid(String detail, [int? nilai]) => ReviewFlag(
        t.id, ReviewReason.dataTidakValid, detail,
        nilai: nilai ?? t.amount.abs());

    if (t.amount < 0 && t.type != TxType.tutupBuku) {
      return tidakValid('nilai negatif ${t.amount}');
    }
    switch (t.type) {
      case TxType.beliPersediaanTunai:
      case TxType.beliPersediaanKredit:
        final item = t.item, qty = t.qty ?? 0;
        if (item == null || qty <= 0) return tidakValid('item/qty pembelian kosong');
        _qty[item] = _qty[item]! + qty;
        _nilai[item] = _nilai[item]! + t.amount;
      case TxType.pakaiPersediaan:
      case TxType.kematianTernak:
        final mati = t.type == TxType.kematianTernak;
        final item = t.item ?? (mati ? StockItem.ternak : null);
        final qty = t.qty ?? 0;
        if (item == null || qty <= 0 || (mati && item != StockItem.ternak)) {
          return tidakValid('item/qty pemakaian kosong atau tidak sesuai', 0);
        }
        final ada = _qty[item]!, nilai = _nilai[item]!;
        if (qty > ada) {
          return ReviewFlag(t.id, ReviewReason.pemakaianMelebihiStok,
              '${item.name}: diminta $qty, tersedia $ada',
              nilai: ada > 0 ? roundHalfAwayFromZero(nilai * qty, ada) : 0);
        }
        final biaya = roundHalfAwayFromZero(nilai * qty, ada);
        _qty[item] = ada - qty;
        _nilai[item] = nilai - biaya;
        biayaPakai[t.id] = biaya;
      case TxType.penjualanKredit:
        _sisaPiutang[t.id] = t.amount;
      case TxType.terimaPiutang:
        final ref = t.refId == null ? null : byId[t.refId];
        if (ref == null || ref.type != TxType.penjualanKredit) {
          return ReviewFlag(t.id, ReviewReason.referensiTidakDitemukan,
              'terima piutang merujuk id ${t.refId} yang bukan penjualan kredit valid',
              nilai: t.amount);
        }
        final sisa = _sisaPiutang[ref.id]!;
        if (t.amount > sisa) {
          return ReviewFlag(t.id, ReviewReason.pelunasanMelebihiPiutang,
              'terima ${t.amount}, sisa piutang $sisa (id ${ref.id})',
              nilai: t.amount);
        }
        _sisaPiutang[ref.id] = sisa - t.amount;
      case TxType.beliAsetTetap:
        final id = t.assetId;
        if (id == null || !_asetDibeli.add(id)) {
          return tidakValid('aset tetap tanpa assetId atau dibeli dua kali ($id)');
        }
      case TxType.penyusutan:
        return tidakValid('penyusutan dihitung otomatis dari aset tetap; entri manual tidak dihitung');
      default:
        break;
    }
    return null;
  }

  ReviewFlag? _terimaRetur(AcctTx t) {
    final asli = byId[t.reversalOf];
    if (asli == null || asli.type != t.type) {
      return ReviewFlag(t.id, ReviewReason.referensiTidakDitemukan,
          'retur merujuk id ${t.reversalOf} yang tidak ada atau beda tipe',
          nilai: t.amount.abs());
    }
    if (t.amount < 0 || !_bisaDibalik.contains(t.type)) {
      return ReviewFlag(t.id, ReviewReason.dataTidakValid,
          'retur ${t.type.code} bernilai ${t.amount} tidak didukung',
          nilai: t.amount.abs());
    }
    final sudah = _dibalik[asli.id] ?? 0;
    final batas = t.type == TxType.penjualanKredit
        ? _sisaPiutang[asli.id]!
        : asli.amount - sudah;
    if (t.amount > batas) {
      return ReviewFlag(t.id, ReviewReason.returMelebihiAsli,
          'retur ${t.amount}, maksimum $batas (asli id ${asli.id} = ${asli.amount})',
          nilai: t.amount);
    }
    _dibalik[asli.id] = sudah + t.amount;
    if (t.type == TxType.penjualanKredit) {
      _sisaPiutang[asli.id] = _sisaPiutang[asli.id]! - t.amount;
    } else if (t.type == TxType.terimaPiutang) {
      _sisaPiutang[asli.refId!] = _sisaPiutang[asli.refId!]! + t.amount;
    }
    return null;
  }
}

ExpenseKind _bebanPakai(StockItem item) => switch (item) {
      StockItem.pakan => ExpenseKind.pakan,
      StockItem.obat => ExpenseKind.obat,
      StockItem.ternak => ExpenseKind.bpp,
    };

/// Laporan murni dari transaksi + aset. Transaksi diproses menurut (tanggal, `id`) naik.
/// Laba Rugi mencakup periode [from, asOf]; Posisi Keuangan per `asOf`.
Report buildReport(
  List<AcctTx> txs,
  List<FixedAsset> assets, {
  required DateTime asOf,
  DateTime? from,
}) {
  final book = _Book(txs, asOf);
  final mulai = from == null ? null : _day(from);
  var kas = 0, piutang = 0, asetBruto = 0, utang = 0, modal = 0, prive = 0;
  var labaKumulatif = 0, pendapatan = 0;
  final persediaan = {for (final i in StockItem.values) i: 0};
  final beban = <ExpenseKind, int>{};
  final asetDipakai = <int>{};

  for (final t in book.valid) {
    final asli = book.asli(t);
    final a = (t.reversalOf == null ? 1 : -1) * (book.biayaPakai[t.id] ?? t.amount);
    final diPeriode = mulai == null || _day(t.date) >= mulai;
    void catatPendapatan(int x) {
      labaKumulatif += x;
      if (diPeriode) pendapatan += x;
    }

    void catatBeban(ExpenseKind k, int x) {
      labaKumulatif -= x;
      if (diPeriode) beban[k] = (beban[k] ?? 0) + x;
    }

    switch (asli.type) {
      case TxType.penjualanTunai:
        kas += a;
        catatPendapatan(a);
      case TxType.penjualanKredit:
        piutang += a;
        catatPendapatan(a);
      case TxType.terimaPiutang:
        kas += a;
        piutang -= a;
      case TxType.beliPersediaanTunai:
        persediaan[asli.item!] = persediaan[asli.item!]! + a;
        kas -= a;
      case TxType.beliPersediaanKredit:
        persediaan[asli.item!] = persediaan[asli.item!]! + a;
        utang += a;
      case TxType.pakaiPersediaan:
        persediaan[asli.item!] = persediaan[asli.item!]! - a;
        catatBeban(asli.expense ?? _bebanPakai(asli.item!), a);
      case TxType.kematianTernak:
        persediaan[StockItem.ternak] = persediaan[StockItem.ternak]! - a;
        catatBeban(ExpenseKind.kerugianTernak, a);
      case TxType.bebanOperasional:
        catatBeban(asli.expense ?? ExpenseKind.lain, a);
        if (asli.onCredit) {
          utang += a;
        } else {
          kas -= a;
        }
      case TxType.beliAsetTetap:
        asetBruto += a;
        if (asli.onCredit) {
          utang += a;
        } else {
          kas -= a;
        }
        asetDipakai.add(asli.assetId!);
      case TxType.setorModal:
        kas += a;
        modal += a;
      case TxType.prive:
        kas -= a;
        prive += a;
      case TxType.terimaPinjaman:
        kas += a;
        utang += a;
      case TxType.bayarCicilanPokok:
        kas -= a;
        utang -= a;
      case TxType.bebanBunga:
        kas -= a;
        catatBeban(ExpenseKind.bunga, a);
      case TxType.penyusutan: // selalu ditandai di _Book
      case TxType.tutupBuku: // arsip; saldo laba sudah kumulatif
        break;
    }
  }

  var akumulasi = 0;
  for (final aset in assets.where((x) => asetDipakai.contains(x.id))) {
    final acc = accumulatedDepreciation(aset, asOf);
    akumulasi += acc;
    labaKumulatif -= acc;
    final periode =
        acc - (from == null ? 0 : accumulatedDepreciation(aset, _dayBefore(from)));
    if (periode != 0) {
      beban[ExpenseKind.penyusutan] = (beban[ExpenseKind.penyusutan] ?? 0) + periode;
    }
  }

  beban.removeWhere((_, v) => v == 0); // baris yang habis oleh retur tidak ditampilkan
  final bebanTotal = beban.values.fold<int>(0, (a, b) => a + b);
  final saldoLaba = labaKumulatif - prive;
  final totalAset = kas +
      piutang +
      persediaan.values.fold<int>(0, (a, b) => a + b) +
      asetBruto -
      akumulasi;
  final totalLE = utang + modal + saldoLaba;
  return Report(
    kas: kas,
    piutang: piutang,
    persediaan: Map.unmodifiable(persediaan),
    asetTetapBruto: asetBruto,
    akumulasiPenyusutan: akumulasi,
    totalAset: totalAset,
    utang: utang,
    modalDisetor: modal,
    prive: prive,
    saldoLaba: saldoLaba,
    totalLiabilitasEkuitas: totalLE,
    balanced: totalAset == totalLE,
    pendapatan: pendapatan,
    beban: Map.unmodifiable(beban),
    bebanTotal: bebanTotal,
    labaBersih: pendapatan - bebanTotal,
    perluDitinjau: List.unmodifiable(book.flags),
  );
}

/// Saldo buku kas, dihitung terpisah dari buildReport (invarian D3).
/// Memakai validasi yang sama (transaksi perlu_ditinjau tidak dihitung).
int cashBookBalance(List<AcctTx> txs, {required DateTime asOf}) =>
    cashBookSummary(txs, asOf: asOf).saldo;

/// Kas masuk/keluar dari buku kas (untuk dashboard). Retur dicatat sebagai
/// pengurang di sisi yang sama dengan transaksi aslinya.
CashSummary cashBookSummary(List<AcctTx> txs, {required DateTime asOf}) {
  final book = _Book(txs, asOf);
  var masuk = 0, keluar = 0;
  for (final t in book.valid) {
    final asli = book.asli(t);
    final arah = cashDirection(asli.type, onCredit: asli.onCredit);
    final a = t.reversalOf == null ? t.amount : -t.amount;
    if (arah > 0) masuk += a;
    if (arah < 0) keluar += a;
  }
  return CashSummary(masuk, keluar);
}

/// Arah kas satu tipe transaksi: 1 masuk, -1 keluar, 0 tidak menyentuh kas.
int cashDirection(TxType type, {bool onCredit = false}) => switch (type) {
      TxType.penjualanTunai ||
      TxType.terimaPiutang ||
      TxType.setorModal ||
      TxType.terimaPinjaman =>
        1,
      TxType.beliPersediaanTunai ||
      TxType.prive ||
      TxType.bayarCicilanPokok ||
      TxType.bebanBunga =>
        -1,
      TxType.bebanOperasional || TxType.beliAsetTetap => onCredit ? 0 : -1,
      _ => 0,
    };

/// Tolak (lempar PeriodLockedException) bila `date` <= lockedUntil (per hari).
void checkWrite({required DateTime date, DateTime? lockedUntil}) {
  if (lockedUntil != null && _day(date) <= _day(lockedUntil)) {
    throw PeriodLockedException(date, lockedUntil);
  }
}

/// Edit/hapus: tanggal lama DAN tanggal baru harus di luar periode terkunci.
void checkEdit({
  required DateTime oldDate,
  required DateTime newDate,
  DateTime? lockedUntil,
}) {
  checkWrite(date: oldDate, lockedUntil: lockedUntil);
  checkWrite(date: newDate, lockedUntil: lockedUntil);
}

/// Entri tutup buku (arsip): tidak menghapus transaksi, tidak mengubah total aset/saldo laba.
/// `amount` = laba bersih periode laporan `r` (boleh negatif).
AcctTx buildClosingEntry(Report r, {required int id, required DateTime date}) =>
    AcctTx(id: id, date: date, type: TxType.tutupBuku, amount: r.labaBersih);
