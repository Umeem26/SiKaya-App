// Alasan dalam bahasa petani untuk yang tidak bisa dipilih, diubah, atau
// dihapus: catatan otomatis (penyusutan, tutup buku), periode yang sudah ditutup
// buku, dan pilihan yang belum tersedia. Satu tempat agar kalimat dan tombol
// pintasnya seragam di semua layar. Tampil lewat [tampilkanAlasan] (lembar bawah).
import 'package:flutter/material.dart';

import '../accounting/models.dart';
import '../halaman_utama.dart' show TabUtama, pindahKeTab;
import 'komponen.dart';

/// Kalimat pendek di kartu/panel info untuk jenis yang dicatat otomatis.
String ringkasOtomatis(TxType? t) => switch (t) {
      TxType.penyusutan => 'SiKaya menghitungnya sendiri setiap bulan dari data kandang dan alat.',
      TxType.tutupBuku => 'Dibuat sendiri oleh SiKaya saat Anda menutup buku di menu Lainnya.',
      _ => 'Dicatat sendiri oleh SiKaya.',
    };

/// Kalimat penjelas kelompok "Dicatat otomatis" di layar "Apa yang terjadi?".
const penjelasDicatatOtomatis = 'SiKaya mencatat ini sendiri, jadi tidak perlu dipilih.';

/// Penyusutan atau tutup buku: kenapa tidak dicatat sendiri, dan di mana melihatnya.
Future<void> jelaskanOtomatis(BuildContext context, TxType? t) => t == TxType.penyusutan
    ? tampilkanAlasan(
        context,
        judul: 'Penyusutan dihitung otomatis',
        isi: 'Kandang, alat, dan kendaraan makin lama makin aus. Setiap bulan SiKaya menghitung '
            'sendiri bagian nilai yang sudah terpakai (penyusutan) dari data aset Anda, jadi tidak '
            'perlu dicatat. Rinciannya ada di tab Aset, dan ikut dihitung sebagai biaya di Laporan.',
        aksi: 'Lihat di tab Aset',
        ikonAksi: Icons.warehouse_rounded,
        onAksi: () => pindahKeTab(TabUtama.aset),
      )
    : tampilkanAlasan(
        context,
        judul: 'Tutup buku dibuat dari menu Lainnya',
        isi: 'Catatan tutup buku dibuat sendiri oleh SiKaya saat Anda menutup buku, misalnya setiap '
            'akhir bulan. Untung atau rugi sampai tanggal itu dipindah ke saldo laba, lalu catatan '
            'sampai tanggal itu dikunci supaya angka laporannya tidak berubah lagi.',
        aksi: 'Buka Tutup buku di Lainnya',
        ikonAksi: Icons.arrow_forward_rounded,
        onAksi: () => pindahKeTab(TabUtama.lainnya),
      );

/// Label lencana periode yang sudah ditutup: "Ditutup s.d. 30 Sep 2026".
String labelDitutup(DateTime sampai) => 'Ditutup s.d. ${tanggalPendek(isoTanggal(sampai))}';

/// true bila tanggal [iso] (yyyy-MM-dd) termasuk periode yang sudah ditutup buku.
bool sudahDitutup(String iso, DateTime? ditutupSampai) {
  final t = DateTime.tryParse(iso);
  return t != null && ditutupSampai != null && !t.isAfter(ditutupSampai);
}

/// Periode sampai [sampai] sudah ditutup buku: catatannya dikunci.
Future<void> jelaskanDitutup(BuildContext context, DateTime sampai) {
  final tgl = tanggalPanjang(isoTanggal(sampai));
  return tampilkanAlasan(
    context,
    judul: 'Sudah ditutup buku sampai $tgl',
    isi: 'Catatan sampai $tgl tetap tersimpan dan tetap dihitung di laporan, tetapi dikunci supaya '
        'angkanya tidak berubah lagi: tidak bisa ditambah, diubah, atau dihapus.\n\n'
        'Bila ada yang salah, catat koreksi lewat "Retur / batalkan sebagian transaksi" dengan tanggal '
        'sesudah $tgl.',
    aksi: 'Lihat Tutup buku di Lainnya',
    ikonAksi: Icons.arrow_forward_rounded,
    onAksi: () => pindahKeTab(TabUtama.lainnya),
  );
}

/// Tutup buku diminta lagi padahal sudah ditutup sampai hari ini.
Future<void> jelaskanSudahDitutupHariIni(BuildContext context, DateTime sampai) {
  final tgl = tanggalPanjang(isoTanggal(sampai));
  return tampilkanAlasan(
    context,
    judul: 'Buku sudah ditutup sampai $tgl',
    isi: 'Semua catatan sampai $tgl sudah ditutup buku dan dikunci. Tutup buku berikutnya bisa '
        'dilakukan mulai besok. Angka yang sudah ditutup bisa dilihat di Laporan.',
    aksi: 'Lihat Laporan',
    ikonAksi: Icons.bar_chart_rounded,
    onAksi: () => pindahKeTab(TabUtama.laporan),
  );
}

/// Retur belum bisa dipilih: belum ada catatan yang bisa dibatalkan.
Future<void> jelaskanBelumAdaRetur(BuildContext context) => tampilkanAlasan(
      context,
      judul: 'Belum ada catatan yang bisa diretur',
      isi: 'Retur dipakai untuk membatalkan sebagian catatan yang sudah ada, misalnya pembeli '
          'mengembalikan sebagian ayam atau pakan dikembalikan ke toko. Saat ini belum ada catatan '
          'yang bisa dibatalkan.',
      aksi: 'Lihat daftar catatan',
      ikonAksi: Icons.list_rounded,
      onAksi: () => pindahKeTab(TabUtama.catat),
    );

/// Terima piutang belum bisa dipilih: belum ada penjualan yang belum dibayar.
Future<void> jelaskanBelumAdaPiutang(BuildContext context, {required VoidCallback catatJualBelumDibayar}) =>
    tampilkanAlasan(
      context,
      judul: 'Belum ada yang berutang kepada Anda',
      isi: 'Pilihan ini untuk mencatat pembeli yang melunasi bayarannya. Saat ini belum ada penjualan '
          'yang belum dibayar. Catat dulu penjualannya lewat "Jual, belum dibayar (piutang)".',
      aksi: 'Catat jual belum dibayar',
      ikonAksi: Icons.request_quote_rounded,
      onAksi: catatJualBelumDibayar,
    );
