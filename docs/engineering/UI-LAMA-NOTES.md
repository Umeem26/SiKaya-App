# Acuan visual UI lama (commit a18a534, sebelum d1e4fc5)

> Foto acuan yang disebut di bawah tidak lagi disimpan di repo; ada di riwayat git
> (commit `5ed5777`, folder `docs/ref-lama/`).

Dibangun dari `git worktree` pada `d1e4fc5^`, dijalankan di emulator Pixel 9 (Android 15),
diisi 1 penjualan dan 1 data ternak. Tangkapan layar di folder ini:

| File | Layar |
|---|---|
| 01-onboarding.png | Isi nama peternakan |
| 02-beranda.png, 02b-beranda-data.png | Dashboard |
| 03-aset.png, 04-form-aset.png | Manajemen Aset (daftar, form) |
| 05-keuangan.png, 06-catat.png | Keuangan (daftar, form) |
| 07-laporan-labarugi.png, 08-laporan-neraca.png, 09-laporan-aset-tetap.png | Pusat Laporan |
| 10-pengaturan.png | Pengaturan |

Catatan teknis: build sukses pada percobaan pertama. Layar hitam yang muncul di awal disebabkan
emulator yang dipulihkan dari snapshot (GPU), bukan kode lama; sesudah cold boot semua tampil.

## Bahasa visual yang dipertahankan
- **Header merek melengkung.** Gradien vertikal biru `#1E549F` → `#153E75`, tinggi ±280dp,
  sudut bawah 40dp. Sapaan kecil ("Halo, Juragan") + nama usaha tebal putih, avatar bulat putih.
- **Kartu pahlawan menumpuk di atas header.** Gradien diagonal `#4FA3D1` → `#1E549F`, sudut 25dp,
  bayangan biru lembut (blur 20, offset y 10). Label kecil, angka besar putih, ikon dompet.
- **Kartu statistik kecil bertiga** (Populasi, Masuk, Keluar): putih, sudut 15dp, bayangan sangat
  tipis, ikon berwarna di atas, label kecil, nilai tebal berwarna.
- **Panel putih bersudut atas 30dp** yang "naik" di atas latar `#F8FAFC` untuk menu.
- **Ubin ikon**: lingkaran/kotak bersudut 12-15dp dengan warna ikon 10% opasitas di belakang ikon
  (daftar aset, Pengaturan). Ini yang membuat daftar terasa "jadi", bukan wireframe.
- **Chip pil** untuk jumlah dan kondisi ("500 Ekor", "Baik"): latar warna 10%, teks tebal berwarna.
- **Kartu daftar tanpa garis tepi**, putih di atas latar abu-biru, sudut 20dp, bayangan tipis.
- **Kelompok menu dengan judul seksi** ("Manajemen Data", "Zona Bahaya") dan baris ListTile
  dengan ubin ikon + judul + subjudul + chevron.
- **Laporan berkop**: kotak kop bergaris (nama usaha, judul laporan, periode, rata tengah),
  seksi berhuruf ("A. Pendapatan"), angka rata kanan, garis bawah tunggal sebelum subtotal,
  total dengan garis atas/bawah tebal. Kertas putih bergaris tepi di atas latar abu.
- **Pilihan bersegmen pil** di header biru (Laporan Keuangan / Asset Tetap).

## Yang TIDAK diambil (gagal aksesibilitas, lihat UI-PLAN.md bagian 7)
- Teks putih di atas oranye `#FA9C1B` (2,14:1), teks `white70`/`grey[400]`, ukuran 11-14sp tetap.
- Tab geser berhuruf kapital kecil, aksi ikon-saja 18px (ubah/hapus), FAB merah "Export PDF"
  yang menutupi angka total, kode akun di laporan petani, "Laporan Asset Tetap" yang isinya
  inventaris (kosong walau ada aset).

## Peta data aset (bagian 0b)
| Data | Tabel | Masuk laporan? | Sumber angka di UI baru |
|---|---|---|---|
| Inventaris (foto, jumlah, kondisi, kategori Ternak/Habis pakai/Aset Tetap) | `assets` | Tidak | Hanya daftar barang; tidak dijumlahkan dengan uang |
| Aset tetap keuangan (nama, siap pakai, umur bulan) | `fixed_assets` + transaksi `beli_aset_tetap` (harga) | Ya | `asetTercatat` + `depreciationSchedule` mesin |
| Persediaan pakan/obat/ternak (nilai) | transaksi beli/pakai/mati | Ya | `Report.persediaan` mesin |
| Jumlah stok (kg, dosis, ekor) | transaksi yang sama | Ya (lewat nilai) | jumlah qty transaksi sah menurut mesin (kolom `perlu_ditinjau` = hasil mesin) |

Kesimpulan: dua data terpisah; tidak ada kolom yang menautkan `assets` ke `fixed_assets`.
Menyatukannya butuh perubahan skema, tetapi tidak diperlukan: tab Aset dan Beranda cukup
menampilkan data mesin. Jumlah ternak diambil dari stok ternak mesin (ekor), bukan inventaris,
agar satu sumber kebenaran. Foto aset tetap disimpan sebagai file `foto_aset/aset_<id aset>_<id catatan beli>.jpg` di
folder dokumen aplikasi (tanpa kolom DB; sama seperti foto inventaris yang juga di luar DB dan
tidak ikut cadangan). Inventaris lama tetap dapat dibuka dari tab Aset, berlabel
"tidak masuk laporan".
