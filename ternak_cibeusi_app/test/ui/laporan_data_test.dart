// S3: data laporan dua lapis. Angka ringkasan (bahasa petani) = angka laporan
// resmi = angka PDF untuk data yang sama; periode dihitung benar.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/calk.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/laporan_data.dart';
import 'package:ternak_cibeusi_app/laporan_pdf.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import '../accounting/closing_test.dart' show seedCampuran;
import '../accounting/db_helpers.dart';
import '../accounting/helpers.dart';

/// Januari = skenario campuran; Februari: jual tunai, biaya, jual kredit, pakai obat tanpa stok.
Future<AccountingRepository> repoJanFeb() async {
  final db = await openMemoryDb();
  addTearDown(db.close);
  final repo = AccountingRepository(() async => db);
  await seedCampuran(repo);
  for (final t in const [
    TransactionModel(txType: TxType.penjualanTunai, amount: 500000, date: '2026-02-10'),
    TransactionModel(
        txType: TxType.bebanOperasional, amount: 200000, date: '2026-02-12', expenseKind: ExpenseKind.listrikAir),
    TransactionModel(txType: TxType.penjualanKredit, amount: 300000, date: '2026-02-14'),
    TransactionModel(txType: TxType.pakaiPersediaan, amount: 0, qty: 999, item: StockItem.obat, date: '2026-02-14'),
    TransactionModel(txType: TxType.prive, amount: 100000, date: '2026-02-15'),
  ]) {
    await repo.insertTransaction(t);
  }
  return repo;
}

/// Ringkasan dan laporan resmi dari DataLaporan yang sama harus cocok baris demi baris.
void cekCocok(DataLaporan d) {
  final pk = d.posisiKeuangan, lr = d.labaRugi, pe = d.perubahanEkuitas;
  expect(lr.nilai('LABA (RUGI) BERSIH'), d.untungRugi);
  expect(lr.nilai('Jumlah pendapatan'), d.penjualan);
  expect(lr.nilai('Jumlah beban'), d.biaya);
  expect(pk.nilai('Kas'), d.kasAkhir);
  expect(pk.nilai('Piutang usaha'), d.piutang);
  expect(pk.nilai('Utang'), d.utang);
  expect(pk.nilai('Nilai buku aset tetap'), d.nilaiAsetTetap);
  expect([for (final l in labelPersediaan.values) pk.nilai(l)!].reduce((a, b) => a + b), d.nilaiStok);
  // Antar laporan resmi.
  expect(pk.nilai('JUMLAH ASET'), pk.nilai('JUMLAH LIABILITAS DAN EKUITAS'));
  expect(pe.nilai('JUMLAH EKUITAS'), pk.nilai('Jumlah ekuitas'));
  expect(pe.nilai('Saldo laba akhir'), pk.nilai('Saldo laba'));
  expect(pe.nilai('Laba (rugi) bersih periode ini'), d.untungRugi);
  // Ikhtisar CaLK = ringkasan.
  final ikhtisar = {for (final r in d.calk.firstWhere((s) => s.judul.startsWith('7.')).rincian) r.label: r.nilai};
  expect(ikhtisar['Kas'], d.kasAkhir);
  expect(ikhtisar['Persediaan'], d.nilaiStok);
  expect(ikhtisar['Aset tetap (nilai buku)'], d.nilaiAsetTetap);
  expect(ikhtisar['Utang'], d.utang);
  expect(ikhtisar['Piutang usaha'], d.piutang);
  expect(ikhtisar['Laba (rugi) bersih periode'], d.untungRugi);
}

void main() {
  sqfliteFfiInit();

  test('hitungPeriode: bulan ini, bulan lalu (lintas tahun), tahun ini, pilih tanggal', () {
    final h = DateTime(2026, 1, 15, 13, 45);
    expect(hitungPeriode(PilihanPeriode.bulanIni, h), (dari: d('2026-01-01'), sampai: d('2026-01-15')));
    expect(hitungPeriode(PilihanPeriode.bulanLalu, h), (dari: d('2025-12-01'), sampai: d('2025-12-31')));
    expect(hitungPeriode(PilihanPeriode.tahunIni, h), (dari: d('2026-01-01'), sampai: d('2026-01-15')));
    expect(hitungPeriode(PilihanPeriode.bulanLalu, DateTime(2026, 3, 31)),
        (dari: d('2026-02-01'), sampai: d('2026-02-28')));
    expect(
        hitungPeriode(PilihanPeriode.pilihTanggal, h, dari: DateTime(2026, 1, 3, 9), sampai: DateTime(2026, 1, 9, 22)),
        (dari: d('2026-01-03'), sampai: d('2026-01-09')));
  });

  test('angka resmi: titik ribuan, negatif dalam kurung', () {
    expect(angkaResmi(0), 'Rp0');
    expect(angkaResmi(1234567), 'Rp1.234.567');
    expect(angkaResmi(-100000), '(Rp100.000)');
  });

  test('Januari: ringkasan = laporan resmi = angka acuan', () async {
    final repo = await repoJanFeb();
    final dt = await muatDataLaporan(repo, dari: d('2026-01-01'), sampai: d('2026-01-31'), namaUsaha: 'Cibeusi');
    cekCocok(dt);
    expect((dt.uangMasuk, dt.uangKeluar, dt.kasAkhir), (10000000, 3000000, 7000000));
    expect((dt.untungRugi, dt.nilaiStok, dt.nilaiAsetTetap, dt.utang, dt.piutang),
        (2500000, 600000, 1100000, 1500000, 0));
    expect(dt.posisiKeuangan.nilai('JUMLAH ASET'), 8700000);
    expect(dt.perubahanEkuitas.nilai('Saldo laba akhir'), 2200000);
    expect(dt.perubahanEkuitas.nilai('Setoran modal periode ini'), 5000000);
    expect(dt.perubahanEkuitas.nilai('Prive (penarikan pemilik)'), -300000);
  });

  test('Februari: saldo awal dari Januari, perlu dicek tidak dihitung, ringkasan = resmi', () async {
    final repo = await repoJanFeb();
    final dt = await muatDataLaporan(repo, dari: d('2026-02-01'), sampai: d('2026-02-15'), namaUsaha: 'Cibeusi');
    cekCocok(dt);
    expect((dt.uangMasuk, dt.uangKeluar, dt.kasAkhir), (500000, 300000, 7200000));
    expect((dt.untungRugi, dt.piutang, dt.nilaiAsetTetap), (500000, 300000, 1000000));
    expect(dt.r.peringatanTinjau!.jumlahTransaksi, 1);
    final pe = dt.perubahanEkuitas;
    expect((pe.nilai('Modal disetor awal'), pe.nilai('Setoran modal periode ini')), (5000000, 0));
    expect((pe.nilai('Saldo laba awal'), pe.nilai('Prive (penarikan pemilik)')), (2200000, -100000));
    expect(pe.nilai('Saldo laba akhir'), 2600000);
  });

  test('PDF: satu file berisi keempat laporan + CaLK dengan angka yang sama', () async {
    final repo = await repoJanFeb();
    final dt = await muatDataLaporan(repo, dari: d('2026-02-01'), sampai: d('2026-02-15'), namaUsaha: 'Cibeusi');
    final pdf = await buatPdfLaporan(dt, kompres: false);
    final isi = latin1.decode(pdf);
    expect(isi.startsWith('%PDF'), isTrue);
    expect(namaFilePdf(dt), 'laporan_keuangan_2026-02-01_2026-02-15.pdf');
    // Teks huruf bawaan ditulis apa adanya; Text pdf memecah per kata.
    for (final kata in ['Posisi', 'Laba', 'Rugi', 'Catatan', 'Perubahan', 'Ekuitas', 'Perhatian:']) {
      expect(isi.contains('($kata)'), isTrue, reason: kata);
    }
    for (final n in [dt.kasAkhir, dt.untungRugi, dt.posisiKeuangan.nilai('JUMLAH ASET')!, dt.nilaiStok]) {
      expect(isi.contains('(${angkaResmi(n)})'), isTrue, reason: angkaResmi(n));
    }
    expect(RegExp(r'/Type\s*/Page\b').allMatches(isi).length, greaterThanOrEqualTo(4));
  });

  test('teksPdf mengganti tanda di luar Latin-1', () {
    expect(teksPdf('−Rp5.000 – 1–4 Okt'), '-Rp5.000 - 1-4 Okt');
    expect(teksPdf('Ayam 🐔'), 'Ayam ??');
  });

  test('CaLK tetap fungsi murni dari repository', () async {
    final repo = await repoJanFeb();
    final dt = await muatDataLaporan(repo, dari: d('2026-01-01'), sampai: d('2026-01-31'), namaUsaha: 'Cibeusi');
    expect(calkText(dt.calk), contains('Cibeusi'));
  });
}
