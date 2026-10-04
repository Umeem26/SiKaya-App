# UI-PLAN Fase 3 — SiKaya

Rencana tampilan saja; belum ada kode UI diubah. Logika (lib/accounting, lib/database) tidak berubah; UI hanya memanggil `AccountingRepository`, `BackupService`, dan merender `tx_form_spec.dart`.

## 1. Pengguna dan aturan dasar
Petani lanjut usia, dipakai siang hari di luar ruangan, HP Android kelas bawah.
- Huruf dasar 18sp (bodyLarge), judul 22-28sp, semua lewat `TextTheme`. Tidak ada `fontSize` tetap; ikut setelan font HP (tidak mengunci `textScaler`). Uji di skala 1,0 / 1,3 / 2,0 tanpa teks terpotong (pakai `Wrap`/gulir, bukan `Row` kaku).
- Area sentuh minimal 48dp; tombol utama 56dp, lebar penuh.
- Ikon selalu disertai tulisan. Tidak ada aksi ikon saja.
- Bahasa sehari-hari ("uang masuk", "untung", "utang"); istilah SAK EMKM hanya di laporan resmi.
- Warna bukan satu-satunya penanda: masuk/keluar memakai tanda +/− dan kata; rugi ditulis "Rugi".
- Tema terang saja; tidak ada teks abu muda.

## 2. Warna dari logo (`assets/icon_ayam.png`, kuantisasi piksel non-latar)
Dominan: oranye koin #F4A753/#E4993A (49%), biru panah #64A3E0/#517BE1 (27%), kuning koin #FAD06C (14%), coral #F77954 (4%); latar logo #FEFEFD.
Warna logo terlalu terang untuk teks di atas putih (#E4993A 2,36; #517BE1 3,98; #64A3E0 2,67; #F77954 2,69), jadi dipakai sebagai isian/ilustrasi saja. Token teks = hue yang sama, digelapkan. Rasio = rumus kontras WCAG 2.x.

| Token | Hex | Dipakai untuk | Pasangan teks/latar dan rasio |
|---|---|---|---|
| primer | #1E4FA3 | tombol utama, app bar | putih di atas primer 7,77; primer di atas latar 7,54 |
| primerMuda | #EAF1FC | pilihan terpilih, chip | primer di atasnya 6,84 |
| aksen | #E4993A | sorotan, ikon besar, garis kartu untung | teks #1F2328 di atasnya 6,71 (teks putih DILARANG: 2,36) |
| aksenTeks | #9A4F00 | teks/ikon aksen | di atas latar 5,83; putih di atasnya 6,01 |
| latar | #FFFBF5 | latar layar | teks 15,32; teksSekunder 7,33 |
| permukaan | #FFFFFF | kartu, dialog | teks 15,80; teksSekunder 7,56 |
| teks | #1F2328 | teks utama | lihat latar/permukaan |
| teksSekunder | #4B5563 | keterangan (ganti `grey[400]`, `white70`) | lihat latar/permukaan |
| sukses / suksesMuda | #1B6B3A / #E7F4EC | uang masuk, untung | di latar 6,34; di suksesMuda 5,78; putih di atas sukses 6,54 |
| peringatan / peringatanMuda | #8A4B00 / #FFF1D6 | perlu ditinjau, periode terkunci | di peringatanMuda 6,09; di latar 6,60 |
| error / errorMuda | #B3261E / #FDECEA | rugi, hapus, gagal | di latar 6,34; di errorMuda 5,72; putih di atas error 6,54 |

Pembanding UI lama: putih di atas `polbanOrange` #FA9C1B = 2,14 (gagal); `polbanBlue` #1E549F di atas putih 7,44 (lolos, mirip primer).

## 3. Struktur layar
Navigasi bawah berlabel: **Beranda · Catat · Laporan · Lainnya**.
1. **Beranda.** Tujuan: tahu keadaan usaha dalam 5 detik. Isi: kartu Uang masuk dan Uang keluar bulan ini (buku kas), kartu Untung/Rugi bulan ini (Laba Rugi bulan berjalan) dengan kalimat "uang masuk belum tentu untung"; banner perlu_ditinjau ("3 catatan perlu dicek", tombol "Lihat") dan banner tidak seimbang; 5 catatan terakhir. Aksi utama: "Catat Kejadian".
2. **Catat: "Apa yang terjadi?"** (alur sudah ada, ditata ulang). Pilihan dikelompokkan: Jual & terima uang · Beli · Pakai stok & ternak mati · Bayar biaya · Modal & pinjaman · Koreksi (retur). Kartu pilihan besar berisi label + penjelasan; pilihan nonaktif tetap tampil dengan alasannya. Form satu kolom dari `tx_form_spec`, tanggal default hari ini. Aksi utama: "Simpan"; sesudahnya pesan jelas, termasuk alasan bila perlu ditinjau.
3. **Riwayat catatan** (pengganti daftar keuangan). Isi: daftar per bulan, tiap baris label, tanggal, "+ Masuk / − Keluar / Tidak lewat kas", status perlu dicek. Aksi: ketuk → detail dengan tombol "Ubah" dan "Hapus" berlabel.
4. **Laporan lapis 1: Ringkasan.** Pilihan periode (bulan ini, bulan lalu, tahun ini, pilih tanggal). Isi berbahasa petani: uang masuk/keluar, untung/rugi, nilai stok dan aset, utang, piutang, masing-masing dengan satu kalimat penjelasan. Aksi utama: "Lihat laporan resmi".
5. **Laporan lapis 2: Laporan resmi SAK EMKM.** Tab: Posisi Keuangan, Laba Rugi, CaLK, Perubahan Ekuitas (tambahan). Aksi utama: "Ekspor PDF" (satu file berisi semua laporan + CaLK, lalu bagikan).
6. **Lainnya.** Cadangan (Ekspor, Pulihkan, tanggal ekspor terakhir), Tutup Buku, Ekspor CSV (untuk Excel), Inventaris (aset non-keuangan lama), nama usaha, Zona bahaya (Reset). Aksi utama: "Ekspor Cadangan".
7. **Splash/Onboarding.** Tetap meminta nama usaha; tambah satu layar ajakan ekspor cadangan rutin.

## 4. Komponen bersama (`lib/ui/`)
- `SikayaTheme`: token warna di atas, `TextTheme` 18sp, `minimumSize` 48dp untuk semua tombol.
- `TombolUtama` / `TombolKedua` / `TombolBahaya`: ikon + teks, lebar penuh, 56/48dp.
- `KartuAngka`: judul, Rupiah besar, kalimat keterangan, warna semantik + kata (Untung/Rugi).
- `KartuPilihan`: pilihan "Apa yang terjadi?" (label, penjelasan, alasan nonaktif).
- `InputRupiah`: dari `_RibuanFormatter` (bilangan bulat, titik ribuan), prefix "Rp", angka besar, keyboard angka.
- `InputTanggal`: default hari ini, tombol cepat "Hari ini" / "Kemarin".
- `DialogKonfirmasi`: judul berupa pertanyaan, isi menyebut akibat, tombol kata kerja ("Hapus", "Pulihkan", bukan "OK"); varian bahaya merah.
- `BannerPeringatan`: perlu ditinjau, tidak seimbang, periode terkunci.
- `BarisLaporan`: label + angka rata kanan; label panjang turun baris.

## 5. Urutan pengerjaan
| Sesi | Isi | Hasil yang bisa dicoba pengguna |
|---|---|---|
| S1 | Tema, komponen dasar, navigasi bawah, Beranda baru, splash/onboarding; hapus `finance_page.dart` (tidak diimpor di mana pun) | Buka aplikasi: Beranda baru menampilkan masuk/keluar/untung bulan ini + peringatan; huruf ikut setelan HP |
| S2 | "Apa yang terjadi?" berkelompok, form dengan `InputRupiah`/`InputTanggal`, Riwayat + detail Ubah/Hapus | Mencatat semua jenis kejadian dan mengoreksinya tanpa ikon kecil |
| S3 | Laporan dua lapis, PDF gabungan + bagikan | Ringkasan bahasa petani → laporan resmi + CaLK → satu PDF |
| S4 | Lainnya: cadangan, pulihkan, tutup buku, CSV; Inventaris (form/daftar/detail aset) | Semua menu pengaturan dan inventaris memakai dialog/komponen baru |
Setiap sesi: tes widget pada skala huruf 2,0 tanpa overflow, uji di HP siang hari, analyzer 0 isu untuk file yang disentuh.

## 6. Dipertahankan dari UI lama (sudah baik)
1. Form dirender dari tabel `tx_form_spec.dart` (`form_finance_page.dart`): tampilan bisa diganti tanpa menyentuh validasi.
2. `_RibuanFormatter`: input Rupiah bilangan bulat bertitik ribuan, tanpa `double`.
3. Layar "Apa yang terjadi?": label bahasa petani + penjelasan; pilihan nonaktif disertai alasan.
4. Dialog yang menyebut akibat persis: tutup buku, tawaran cadangan, pulihkan, hapus aset tetap.
5. Peringatan perlu_ditinjau / tidak seimbang yang menampilkan alasan dan nilai, bukan menyembunyikan angka.

## 7. Diganti
1. Warna ditulis ulang per file (`polbanBlue`, `polbanOrange`, `Colors.teal`...) dan teks putih di atas oranye (2,14:1) → token tema.
2. Huruf tetap dan kecil (`fontSize` 10-12, teks `white70`/`grey[400]`) → `TextTheme` yang ikut setelan font.
3. Aksi ikon saja 18px lewat `GestureDetector` (ubah/hapus di daftar keuangan) → tombol berlabel ≥48dp.
4. Laporan gaya "Excel" dengan kode akun, fungsi PDF satu baris, dan toggle "Laporan Asset Tetap" yang sebenarnya menampilkan inventaris → laporan dua lapis.
5. Dashboard lama (`main.dart`): "Total Saldo Kas" sebagai angka utama tanpa untung/rugi, impor `fl_chart` tak terpakai, menu 4 kotak ikon → Beranda baru + navigasi bawah.

## 8. Peta 67 isu analyzer lama
Baseline 67 isu = `flutter analyze` pada commit d1e4fc5 (awal Fase 1). 18 sudah hilang selama Fase 1; 49 tersisa (dicek 2026-10-04). Semua ada di layar yang akan diganti.
| File | Isu (jenis) | Diganti oleh | Sesi | Status |
|---|---|---|---|---|
| main.dart | 9 (6 withOpacity, 2 super-parameter, 1 impor fl_chart tak terpakai) | Beranda + navigasi | S1 | sudah 0 |
| finance_page.dart | 8 (7 withOpacity, 1 super-parameter) | dihapus (kode mati) | S1 | sudah 0 |
| splash_page.dart | 1 (super-parameter) | Splash | S1 | sudah 0 |
| onboarding_page.dart | 2 (1 withOpacity, 1 super-parameter) | Onboarding | S1 | sudah 0 |
| form_finance_page.dart | 3 (2 deprecated, 1 super-parameter) | Catat | S2 | sudah 0 |
| list_finance_page.dart | 5 (4 withOpacity, 1 super-parameter) | Riwayat | S2 | sudah 0 |
| report_page.dart | 2 (1 withOpacity, 1 super-parameter) | Laporan dua lapis | S3 | sudah 0 |
| settings_page.dart | 8 (5 withOpacity, 2 context sesudah await, 1 super-parameter) | Lainnya | S4 | sudah 0 |
| form_asset_page.dart | 20 (10 if tanpa kurung, 7 `value`→`initialValue`, 2 withOpacity, 1 super-parameter) | Inventaris: form | S4 | sisa |
| detail_asset_page.dart | 5 (4 withOpacity, 1 super-parameter) | Inventaris: detail | S4 | sisa |
| list_asset_page.dart | 4 (3 withOpacity, 1 super-parameter) | Inventaris: daftar | S4 | sisa |
| **Jumlah** | **67** (49 sisa + 18 sudah 0) | | | target 0 sesudah S4 |

Dicek ulang sesudah S2 (2026-10-04): 29 isu, semuanya di form_asset_page (20), detail_asset_page (5), list_asset_page (4) = Inventaris S4. File baru/diubah S1-S2 dan semua file tes: 0 isu.

## 9. Kemajuan (centang = terkomit, `flutter test` hijau, `flutter build apk --debug` sukses)
- [x] S1 — tema, komponen dasar, navigasi bawah, Beranda, splash/onboarding
- [x] S2 — "Apa yang terjadi?" berkelompok (`kelompokCatat`), form dengan `InputRupiah`/`InputTanggal`/`PilihanTunggal`, Riwayat per bulan (`list_finance_page.dart`), detail Ubah/Hapus (`detail_catatan_page.dart`), 5 catatan terakhir di Beranda (`ItemCatatan` yang sama). Tes: `test/ui/catat_test.dart`, `riwayat_test.dart`, `alur_catat_test.dart`
- [ ] S3 — laporan dua lapis + PDF
- [ ] S4 — Lainnya (cadangan, pulihkan, tutup buku, CSV), onboarding cadangan berkala, Inventaris
