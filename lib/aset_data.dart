// Data tab Aset dan ringkasan aset di Beranda. Satu kali muat dari
// AccountingRepository (sumber yang sama dengan laporan): nilai buku dari
// asetTercatat mesin, riwayat penyusutan dari depreciationSchedule mesin, nilai
// persediaan dari Report mesin. Inventaris (tabel assets) tidak dipakai di sini
// karena tidak masuk laporan (docs/engineering/UI-LAMA-NOTES.md, "Peta data aset").
// Tanpa Flutter: bisa dites sebagai fungsi murni.
import 'accounting/calk.dart' show asetTercatat;
import 'accounting/engine.dart' show depreciationSchedule;
import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'transaction_model.dart';

/// Satu bulan penyusutan: susut bulan itu, akumulasi, dan nilai buku sesudahnya.
class BarisSusut {
  const BarisSusut(this.bulan, this.susut, this.akumulasi, this.nilaiBuku);
  final DateTime bulan;
  final int susut;
  final int akumulasi;
  final int nilaiBuku;
}

class AsetTetapTampil {
  const AsetTetapTampil({
    required this.id,
    required this.nama,
    required this.hargaPerolehan,
    required this.akumulasi,
    required this.siapPakai,
    required this.umurBulan,
    required this.riwayat,
    this.idBeli,
    this.keterangan = '',
  });
  final int id;
  final String nama;
  final int hargaPerolehan;

  /// Akumulasi penyusutan per tanggal data (dari mesin).
  final int akumulasi;
  final DateTime siapPakai;

  /// null = tidak disusutkan (tanah).
  final int? umurBulan;

  /// Bulan-bulan yang sudah disusutkan sampai tanggal data, urut lama ke baru.
  final List<BarisSusut> riwayat;

  /// id transaksi beli_aset_tetap (untuk membuka catatannya).
  final int? idBeli;
  final String keterangan;

  int get nilaiBuku => hargaPerolehan - akumulasi;
  bool get disusutkan => (umurBulan ?? 0) > 0;

  /// Sisa umur manfaat (bulan); null untuk tanah.
  int? get sisaBulan => disusutkan ? (umurBulan! - riwayat.length).clamp(0, umurBulan!) : null;
}

/// Stok satu barang: jumlah (kg/dosis/ekor) dan nilai (harga beli rata-rata).
class StokTampil {
  const StokTampil({
    required this.item,
    required this.jumlah,
    required this.nilai,
    required this.pakai30Hari,
    required this.pernahDibeli,
  });
  final StockItem item;
  final int jumlah;
  final int nilai;

  /// Jumlah yang dipakai/keluar dalam 30 hari terakhir (sampai tanggal data).
  final int pakai30Hari;
  final bool pernahDibeli;

  /// Perkiraan stok cukup untuk berapa hari menurut pemakaian 30 hari terakhir;
  /// null bila belum ada pemakaian.
  int? get cukupHari => pakai30Hari > 0 ? jumlah * 30 ~/ pakai30Hari : null;

  /// Pakan/obat yang habis atau diperkirakan habis dalam kurang dari 7 hari.
  /// Ternak tidak dihitung (ternak keluar karena dijual, bukan kekurangan).
  bool get menipis =>
      item != StockItem.ternak && pernahDibeli && (jumlah == 0 || (cukupHari != null && cukupHari! < batasMenipisHari));
}

const batasMenipisHari = 7;

class DataAset {
  const DataAset({required this.per, required this.asetTetap, required this.stok, required this.laporan});
  final DateTime per;
  final List<AsetTetapTampil> asetTetap;

  /// Urutan StockItem.values (pakan, obat, ternak).
  final List<StokTampil> stok;

  /// Posisi Keuangan per [per] (mesin); sumber total di bawah.
  final Report laporan;

  int get nilaiBukuAsetTetap => laporan.asetTetapNeto;
  int get hargaPerolehanAsetTetap => laporan.asetTetapBruto;
  int get nilaiPersediaan => laporan.persediaanTotal;
  int get jumlahTernak => stokDari(StockItem.ternak).jumlah;
  List<StokTampil> get menipis => stok.where((s) => s.menipis).toList();

  /// Ada data aset/stok yang pernah dicatat (untuk menampilkan ringkasan atau keadaan kosong).
  bool get adaData => asetTetap.isNotEmpty || stok.any((s) => s.pernahDibeli);

  StokTampil stokDari(StockItem i) => stok.firstWhere((s) => s.item == i);
}

DateTime _hari(DateTime t) => DateTime(t.year, t.month, t.day);

/// Jumlah stok per barang dari catatan yang sah menurut mesin (kolom
/// perlu_ditinjau = hasil mesin): beli menambah, pakai dan ternak mati mengurangi.
/// Aturan sama dengan validasi mesin, yang tidak mengizinkan retur untuk stok.
Map<StockItem, int> jumlahStok(Iterable<TransactionModel> rows, DateTime per) {
  final batas = _hari(per);
  final hasil = {for (final i in StockItem.values) i: 0};
  for (final t in rows) {
    if (t.perluDitinjau || t.reversalOf != null) continue;
    final tgl = DateTime.tryParse(t.date);
    if (tgl == null || tgl.isAfter(batas)) continue;
    final qty = t.qty ?? 0;
    switch (t.txType) {
      case TxType.beliPersediaanTunai || TxType.beliPersediaanKredit:
        if (t.item != null) hasil[t.item!] = hasil[t.item!]! + qty;
      case TxType.pakaiPersediaan:
        if (t.item != null) hasil[t.item!] = hasil[t.item!]! - qty;
      case TxType.kematianTernak:
        hasil[StockItem.ternak] = hasil[StockItem.ternak]! - qty;
      default:
        break;
    }
  }
  return hasil;
}

/// Bagian murni dari [muatDataAset].
DataAset hitungDataAset({
  required List<TransactionModel> rows,
  required List<FixedAssetModel> asetDb,
  required Report laporan,
  required DateTime per,
}) {
  per = _hari(per);
  final input = AccountingRepository.buildEngineInput(rows, asetDb);
  final dbById = {for (final a in asetDb) a.id: a};
  final beliById = {
    for (final r in rows)
      if (r.txType == TxType.beliAsetTetap && r.reversalOf == null && r.assetId != null) r.assetId!: r.id,
  };

  final asetTetap = [
    for (final c in asetTercatat(input.txs, input.assets, laporan, per))
      AsetTetapTampil(
        id: c.aset.id,
        nama: c.aset.name,
        hargaPerolehan: c.aset.cost,
        akumulasi: c.akumulasi,
        siapPakai: c.aset.readyDate,
        umurBulan: c.aset.lifeMonths,
        riwayat: _riwayat(c.aset, per),
        idBeli: beliById[c.aset.id],
        keterangan: dbById[c.aset.id]?.description ?? '',
      ),
  ];

  final qty = jumlahStok(rows, per);
  final awal30 = DateTime(per.year, per.month, per.day - 29);
  int pakai(StockItem i) {
    var n = 0;
    for (final t in rows) {
      if (t.perluDitinjau) continue;
      final tgl = DateTime.tryParse(t.date);
      if (tgl == null || tgl.isBefore(awal30) || tgl.isAfter(per)) continue;
      final barang = t.txType == TxType.kematianTernak ? StockItem.ternak : t.item;
      if ((t.txType == TxType.pakaiPersediaan || t.txType == TxType.kematianTernak) && barang == i) n += t.qty ?? 0;
    }
    return n;
  }

  bool dibeli(StockItem i) => rows.any((t) =>
      !t.perluDitinjau &&
      (t.txType == TxType.beliPersediaanTunai || t.txType == TxType.beliPersediaanKredit) &&
      t.item == i &&
      !(DateTime.tryParse(t.date)?.isAfter(per) ?? true));

  return DataAset(
    per: per,
    laporan: laporan,
    asetTetap: asetTetap,
    stok: [
      for (final i in StockItem.values)
        StokTampil(
          item: i,
          jumlah: qty[i]!,
          nilai: laporan.persediaan[i] ?? 0,
          pakai30Hari: pakai(i),
          pernahDibeli: dibeli(i),
        ),
    ],
  );
}

/// Bulan penyusutan yang sudah lewat per [per], dari jadwal mesin.
List<BarisSusut> _riwayat(FixedAsset a, DateTime per) {
  final jadwal = depreciationSchedule(a);
  if (jadwal.isEmpty || per.isBefore(_hari(a.readyDate))) return const [];
  final bulanBerjalan = (per.year * 12 + per.month) - (a.readyDate.year * 12 + a.readyDate.month) + 1;
  final hasil = <BarisSusut>[];
  var akumulasi = 0;
  for (var i = 0; i < bulanBerjalan && i < jadwal.length; i++) {
    akumulasi += jadwal[i];
    hasil.add(BarisSusut(DateTime(a.readyDate.year, a.readyDate.month + i), jadwal[i], akumulasi, a.cost - akumulasi));
  }
  return hasil;
}

Future<DataAset> muatDataAset(AccountingRepository repo, {required DateTime hariIni}) async {
  final per = _hari(hariIni);
  final p = await repo.loadReport(asOf: per);
  return hitungDataAset(
    rows: await repo.transactions(),
    asetDb: await repo.fixedAssets(),
    laporan: p.report,
    per: per,
  );
}
