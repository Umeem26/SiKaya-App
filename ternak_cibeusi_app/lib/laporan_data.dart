// Data laporan dua lapis (UI-PLAN.md 3.4-3.5). Satu kali muat dari
// AccountingRepository; ringkasan bahasa petani, laporan resmi di layar, dan PDF
// semuanya dibaca dari objek yang sama, jadi angkanya tidak mungkin berbeda.
// Tanpa Flutter: bisa dites sebagai fungsi murni.
import 'accounting/calk.dart';
import 'accounting/models.dart';
import 'accounting/repository.dart';

enum PilihanPeriode { bulanIni, bulanLalu, tahunIni, pilihTanggal }

const labelPeriode = {
  PilihanPeriode.bulanIni: 'Bulan ini',
  PilihanPeriode.bulanLalu: 'Bulan lalu',
  PilihanPeriode.tahunIni: 'Tahun ini',
  PilihanPeriode.pilihTanggal: 'Pilih tanggal',
};

DateTime _hari(DateTime t) => DateTime(t.year, t.month, t.day);

/// Rentang laporan. Periode berjalan berakhir hari ini; [pilihTanggal] memakai [dari]/[sampai].
({DateTime dari, DateTime sampai}) hitungPeriode(
  PilihanPeriode p,
  DateTime hariIni, {
  DateTime? dari,
  DateTime? sampai,
}) {
  final h = _hari(hariIni);
  return switch (p) {
    PilihanPeriode.bulanIni => (dari: DateTime(h.year, h.month, 1), sampai: h),
    PilihanPeriode.bulanLalu => (dari: DateTime(h.year, h.month - 1, 1), sampai: DateTime(h.year, h.month, 0)),
    PilihanPeriode.tahunIni => (dari: DateTime(h.year, 1, 1), sampai: h),
    PilihanPeriode.pilihTanggal => (dari: _hari(dari ?? h), sampai: _hari(sampai ?? h)),
  };
}

class DataLaporan {
  const DataLaporan({
    required this.namaUsaha,
    required this.dari,
    required this.sampai,
    required this.laporan,
    required this.kasAwal,
    required this.calk,
  });
  final String namaUsaha;
  final DateTime dari;
  final DateTime sampai;

  /// Laba Rugi [dari, sampai], Posisi Keuangan per sampai, buku kas per sampai.
  final PeriodReport laporan;

  /// Buku kas per sehari sebelum [dari].
  final CashSummary kasAwal;
  final List<CalkSection> calk;

  Report get r => laporan.report;
  Report? get awal => laporan.opening;

  // --- Lapis 1: ringkasan bahasa petani ---
  int get uangMasuk => laporan.kas.masuk - kasAwal.masuk;
  int get uangKeluar => laporan.kas.keluar - kasAwal.keluar;
  int get kasAkhir => laporan.kas.saldo;
  int get untungRugi => r.labaBersih;
  int get penjualan => r.pendapatan;
  int get biaya => r.bebanTotal;
  int get nilaiStok => r.persediaanTotal;
  int get nilaiAsetTetap => r.asetTetapNeto;
  int get utang => r.utang;
  int get piutang => r.piutang;

  // --- Perubahan ekuitas (saldo awal = Posisi Keuangan sehari sebelum dari) ---
  int get modalAwal => awal?.modalDisetor ?? 0;
  int get setoranModal => r.modalDisetor - modalAwal;
  int get saldoLabaAwal => awal?.saldoLaba ?? 0;
  int get privePeriode => r.prive - (awal?.prive ?? 0);
  int get ekuitas => r.modalDisetor + r.saldoLaba;
}

Future<DataLaporan> muatDataLaporan(
  AccountingRepository repo, {
  required DateTime dari,
  required DateTime sampai,
  required String namaUsaha,
}) async {
  final p = await repo.loadReport(asOf: sampai, from: dari);
  final awal = await repo.loadReport(asOf: DateTime(dari.year, dari.month, dari.day - 1));
  final calk = await repo.loadCalk(asOf: sampai, from: dari, namaUsaha: namaUsaha);
  return DataLaporan(
    namaUsaha: namaUsaha,
    dari: dari,
    sampai: sampai,
    laporan: p,
    kasAwal: awal.kas,
    calk: calk,
  );
}

// --- Lapis 2: laporan resmi SAK EMKM (satu model untuk layar dan PDF) ---

enum JenisBaris { judul, biasa, subtotal, total }

class BarisResmi {
  const BarisResmi(this.label, [this.nilai, this.jenis = JenisBaris.biasa, this.menjorok = 0]);
  const BarisResmi.judul(this.label)
      : nilai = null,
        jenis = JenisBaris.judul,
        menjorok = 0;
  final String label;
  final int? nilai;
  final JenisBaris jenis;
  final int menjorok;
}

class LaporanResmi {
  const LaporanResmi(this.judul, this.keteranganPeriode, this.baris);
  final String judul;

  /// "Per ..." atau "Untuk periode ... s.d. ...".
  final String keteranganPeriode;
  final List<BarisResmi> baris;

  /// Nilai baris berlabel [label] (untuk tes dan pencocokan dengan ringkasan).
  int? nilai(String label) => baris.where((b) => b.label == label).firstOrNull?.nilai;
}

const labelBeban = {
  ExpenseKind.bpp: 'Beban pokok penjualan (ternak)',
  ExpenseKind.pakan: 'Beban pakan',
  ExpenseKind.obat: 'Beban obat & vitamin',
  ExpenseKind.listrikAir: 'Beban listrik dan air',
  ExpenseKind.tenagaKerja: 'Beban tenaga kerja',
  ExpenseKind.perawatan: 'Beban perawatan kandang',
  ExpenseKind.penyusutan: 'Beban penyusutan',
  ExpenseKind.bunga: 'Beban bunga',
  ExpenseKind.kerugianTernak: 'Beban kerugian ternak',
  ExpenseKind.lain: 'Beban lain-lain',
};

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String tanggalResmi(DateTime t) => '${t.day} ${_bulan[t.month - 1]} ${t.year}';

/// Angka laporan resmi: negatif dalam kurung, "(Rp100.000)".
String angkaResmi(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return v < 0 ? '(Rp$b)' : 'Rp$b';
}

extension LaporanResmiDari on DataLaporan {
  String get _periode => 'Untuk periode ${tanggalResmi(dari)} s.d. ${tanggalResmi(sampai)}';

  LaporanResmi get posisiKeuangan => LaporanResmi('Laporan Posisi Keuangan', 'Per ${tanggalResmi(sampai)}', [
        const BarisResmi.judul('ASET'),
        BarisResmi('Kas', r.kas, JenisBaris.biasa, 1),
        BarisResmi('Piutang usaha', r.piutang, JenisBaris.biasa, 1),
        for (final i in StockItem.values) BarisResmi(labelPersediaan[i]!, r.persediaan[i] ?? 0, JenisBaris.biasa, 1),
        BarisResmi('Aset tetap (harga perolehan)', r.asetTetapBruto, JenisBaris.biasa, 1),
        BarisResmi('Akumulasi penyusutan', -r.akumulasiPenyusutan, JenisBaris.biasa, 1),
        BarisResmi('Nilai buku aset tetap', r.asetTetapNeto, JenisBaris.subtotal, 1),
        BarisResmi('JUMLAH ASET', r.totalAset, JenisBaris.total),
        const BarisResmi.judul('LIABILITAS'),
        BarisResmi('Utang', r.utang, JenisBaris.biasa, 1),
        BarisResmi('Jumlah liabilitas', r.utang, JenisBaris.subtotal),
        const BarisResmi.judul('EKUITAS'),
        BarisResmi('Modal disetor', r.modalDisetor, JenisBaris.biasa, 1),
        BarisResmi('Saldo laba', r.saldoLaba, JenisBaris.biasa, 1),
        BarisResmi('Jumlah ekuitas', ekuitas, JenisBaris.subtotal),
        BarisResmi('JUMLAH LIABILITAS DAN EKUITAS', r.totalLiabilitasEkuitas, JenisBaris.total),
      ]);

  LaporanResmi get labaRugi => LaporanResmi('Laporan Laba Rugi', _periode, [
        const BarisResmi.judul('PENDAPATAN'),
        BarisResmi('Pendapatan penjualan', r.pendapatan, JenisBaris.biasa, 1),
        BarisResmi('Jumlah pendapatan', r.pendapatan, JenisBaris.subtotal),
        const BarisResmi.judul('BEBAN'),
        for (final k in ExpenseKind.values)
          if (r.beban[k] != null) BarisResmi(labelBeban[k]!, r.beban[k]!, JenisBaris.biasa, 1),
        BarisResmi('Jumlah beban', r.bebanTotal, JenisBaris.subtotal),
        BarisResmi('LABA (RUGI) BERSIH', r.labaBersih, JenisBaris.total),
      ]);

  LaporanResmi get perubahanEkuitas => LaporanResmi('Laporan Perubahan Ekuitas', _periode, [
        const BarisResmi.judul('MODAL DISETOR'),
        BarisResmi('Modal disetor awal', modalAwal, JenisBaris.biasa, 1),
        BarisResmi('Setoran modal periode ini', setoranModal, JenisBaris.biasa, 1),
        BarisResmi('Modal disetor akhir', r.modalDisetor, JenisBaris.subtotal),
        const BarisResmi.judul('SALDO LABA'),
        BarisResmi('Saldo laba awal', saldoLabaAwal, JenisBaris.biasa, 1),
        BarisResmi('Laba (rugi) bersih periode ini', r.labaBersih, JenisBaris.biasa, 1),
        BarisResmi('Prive (penarikan pemilik)', -privePeriode, JenisBaris.biasa, 1),
        BarisResmi('Saldo laba akhir', r.saldoLaba, JenisBaris.subtotal),
        BarisResmi('JUMLAH EKUITAS', ekuitas, JenisBaris.total),
      ]);

}
