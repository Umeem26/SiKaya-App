// Catatan atas Laporan Keuangan (CaLK) otomatis dari data (SAK EMKM, spec A3).
// Fungsi murni: input = transaksi + aset (input mesin) + laporan, tanpa SQLite.
// Teks kebijakan mengikuti perilaku engine.dart; ubah keduanya bersamaan.
import 'package:intl/intl.dart';

import 'engine.dart';
import 'models.dart';
import 'tx_form_spec.dart' show formatRupiah;

/// Satu baris rincian bernilai Rupiah (mis. saldo persediaan, nilai buku aset).
class CalkRow {
  const CalkRow(this.label, this.nilai, {this.keterangan});
  final String label;
  final int nilai;
  final String? keterangan;
}

class CalkSection {
  const CalkSection(this.judul, {this.paragraf = const [], this.rincian = const []});
  final String judul;
  final List<String> paragraf;
  final List<CalkRow> rincian;
}

/// Aset tetap yang tercatat di Posisi Keuangan per tanggal laporan.
class CalkAset {
  const CalkAset(this.aset, this.akumulasi);
  final FixedAsset aset;
  final int akumulasi;
  bool get disusutkan => (aset.lifeMonths ?? 0) > 0;
  int get nilaiBuku => aset.cost - akumulasi;
}

const labelPersediaan = {
  StockItem.pakan: 'Persediaan Pakan',
  StockItem.obat: 'Persediaan Obat & Vitamin',
  StockItem.ternak: 'Persediaan Ternak',
};

final _tgl = DateFormat('dd-MM-yyyy');

/// Aset tetap yang dihitung mesin per [asOf]: transaksi beli valid (tidak perlu
/// ditinjau) bertanggal <= asOf. Jumlah harga perolehan = Report.asetTetapBruto.
List<CalkAset> asetTercatat(List<AcctTx> txs, List<FixedAsset> assets, Report r, DateTime asOf) {
  final ditinjau = r.perluDitinjau.map((f) => f.txId).toSet();
  final batas = DateTime(asOf.year, asOf.month, asOf.day + 1);
  final dibeli = {
    for (final t in txs)
      if (t.type == TxType.beliAsetTetap &&
          t.reversalOf == null &&
          t.assetId != null &&
          t.date.isBefore(batas) &&
          !ditinjau.contains(t.id))
        t.assetId!,
  };
  return [
    for (final a in assets)
      if (dibeli.contains(a.id)) CalkAset(a, accumulatedDepreciation(a, asOf)),
  ];
}

/// CaLK periode [from, asOf] (Laba Rugi) dan per asOf (Posisi Keuangan).
List<CalkSection> buildCalk({
  required List<AcctTx> txs,
  required List<FixedAsset> assets,
  required Report report,
  required DateTime asOf,
  DateTime? from,
  DateTime? lockedUntil,
  String namaUsaha = 'Usaha peternakan',
}) {
  final r = report;
  final aset = asetTercatat(txs, assets, r, asOf);
  final susut = aset.where((a) => a.disusutkan).toList();
  final tanah = aset.where((a) => !a.disusutkan).toList();
  final periode = from == null
      ? 'sejak awal pencatatan sampai ${_tgl.format(asOf)}'
      : '${_tgl.format(from)} s.d. ${_tgl.format(asOf)}';

  return [
    CalkSection('1. Umum', paragraf: [
      'Laporan keuangan $namaUsaha untuk periode $periode disusun oleh pemilik '
          'menggunakan aplikasi SiKaya. Laporan Posisi Keuangan disajikan per ${_tgl.format(asOf)}.',
    ]),
    CalkSection('2. Dasar Penyusunan', paragraf: [
      'Laporan keuangan disusun berdasarkan Standar Akuntansi Keuangan Entitas Mikro, '
          'Kecil, dan Menengah (SAK EMKM) dengan dasar akrual dan konsep biaya historis '
          '(harga perolehan).',
      'Mata uang pelaporan adalah Rupiah, dibulatkan ke Rupiah penuh.',
      'Laporan terdiri atas Laporan Posisi Keuangan, Laporan Laba Rugi, dan Catatan atas '
          'Laporan Keuangan. Laporan Perubahan Ekuitas disajikan sebagai informasi tambahan.',
    ]),
    CalkSection('3. Persediaan', paragraf: [
      'Persediaan pakan, obat & vitamin, dan ternak/bibit dicatat sebesar harga perolehan '
          'saat dibeli dan diakui sebagai beban saat dipakai atau saat ternak keluar karena terjual.',
      'Biaya persediaan yang dipakai dihitung dengan metode rata-rata tertimbang: total nilai '
          'dibagi total kuantitas tersedia pada saat pemakaian.',
      if (r.persediaanTotal == 0) 'Tidak ada saldo persediaan per ${_tgl.format(asOf)}.',
    ], rincian: [
      for (final i in StockItem.values)
        if ((r.persediaan[i] ?? 0) != 0) CalkRow(labelPersediaan[i]!, r.persediaan[i]!),
      if (r.persediaanTotal != 0) CalkRow('Jumlah persediaan', r.persediaanTotal),
    ]),
    CalkSection('4. Aset Tetap', paragraf: [
      'Aset tetap dicatat sebesar harga perolehan. Penyusutan memakai metode garis lurus '
          'tanpa nilai residu, dimulai pada bulan aset siap dipakai dan dihitung per bulan penuh; '
          'selisih pembulatan dibebankan pada bulan terakhir umur manfaat.',
      'Tanah tidak disusutkan.',
      aset.isEmpty
          ? 'Belum ada aset tetap per ${_tgl.format(asOf)}.'
          : 'Jumlah aset tetap per ${_tgl.format(asOf)}: ${aset.length} aset '
              '(${susut.length} disusutkan garis lurus, ${tanah.length} tidak disusutkan). '
              'Harga perolehan ${formatRupiah(r.asetTetapBruto)}, akumulasi penyusutan '
              '${formatRupiah(r.akumulasiPenyusutan)}, nilai buku ${formatRupiah(r.asetTetapNeto)}.',
    ], rincian: [
      for (final a in aset)
        CalkRow(
          a.aset.name,
          a.nilaiBuku,
          keterangan: '${a.disusutkan ? 'garis lurus ${a.aset.lifeMonths} bulan' : 'tidak disusutkan (tanah)'}; '
              'perolehan ${formatRupiah(a.aset.cost)}, akumulasi ${formatRupiah(a.akumulasi)}, '
              'siap pakai ${_tgl.format(a.aset.readyDate)}',
        ),
    ]),
    const CalkSection('5. Aset Biologis (Kebijakan Manajemen)', paragraf: [
      'SAK EMKM tidak mengatur aset biologis. Sebagai kebijakan manajemen, DOC/bibit dan '
          'ternak dicatat sebagai Persediaan Ternak sebesar biaya perolehan dan dipindahkan ke '
          'Beban Pokok Penjualan saat ternak keluar karena terjual.',
      'Pakan dan obat yang dipakai diakui langsung sebagai Beban Pakan dan Beban Obat pada '
          'periode pemakaian, tidak ditambahkan ke nilai ternak. Alokasi pakan ke nilai ternak '
          'ditunda sampai tersedia pencatatan per batch/siklus dan jumlah populasi.',
      'Akibatnya, laba per periode dapat berfluktuasi: pada periode pemeliharaan beban pakan '
          'sudah diakui sementara pendapatan baru diakui saat ternak terjual.',
      'Kematian ternak diakui sebagai Beban Kerugian Ternak sebesar biaya rata-rata tertimbang '
          'ternak yang mati.',
    ]),
    const CalkSection('6. Pendapatan, Liabilitas, dan Ekuitas', paragraf: [
      'Pendapatan diakui saat barang diserahkan kepada pembeli; penjualan yang belum dibayar '
          'dicatat sebagai piutang.',
      'Pinjaman dicatat sebagai utang sebesar jumlah yang harus dibayar; cicilan pokok mengurangi '
          'utang, bunga diakui sebagai beban.',
      'Setoran modal pemilik dicatat sebagai modal disetor dan penarikan pemilik (prive) '
          'mengurangi saldo laba; keduanya bukan pendapatan atau beban.',
    ]),
    CalkSection('7. Ikhtisar Akun Penting', rincian: [
      CalkRow('Kas', r.kas),
      CalkRow('Piutang usaha', r.piutang),
      CalkRow('Persediaan', r.persediaanTotal),
      CalkRow('Aset tetap (nilai buku)', r.asetTetapNeto),
      CalkRow('Utang', r.utang),
      CalkRow('Modal disetor', r.modalDisetor),
      CalkRow('Prive kumulatif', r.prive),
      CalkRow('Saldo laba', r.saldoLaba),
      CalkRow('Laba (rugi) bersih periode', r.labaBersih),
    ]),
    CalkSection('8. Batasan', paragraf: [
      'Retur yang barangnya kembali ke stok belum didukung. Retur hanya tersedia untuk '
          'transaksi tanpa efek persediaan atau aset tetap.',
      'Tutup buku mengunci periode secara permanen; koreksi atas periode terkunci dicatat '
          'sebagai transaksi pembalik pada periode berjalan.',
      lockedUntil == null
          ? 'Belum ada periode yang ditutup buku.'
          : 'Periode sampai ${_tgl.format(lockedUntil)} sudah ditutup buku.',
      if (r.peringatanTinjau != null) r.peringatanTinjau!.pesan,
      if (!r.balanced)
        'Laporan Posisi Keuangan tidak seimbang: aset ${formatRupiah(r.totalAset)}, '
            'liabilitas dan ekuitas ${formatRupiah(r.totalLiabilitasEkuitas)}.',
    ]),
  ];
}

/// Seluruh CaLK sebagai teks biasa (dipakai tes dan ekspor).
String calkText(List<CalkSection> s) => [
      for (final x in s) ...[
        x.judul,
        ...x.paragraf,
        for (final r in x.rincian)
          '${r.label}: ${formatRupiah(r.nilai)}${r.keterangan == null ? '' : ' (${r.keterangan})'}',
      ],
    ].join('\n');
