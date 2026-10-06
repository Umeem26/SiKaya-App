# AUDIT SiKaya (ternak_cibeusi_app) — read-only

Cakupan: pubspec, analysis_options, manifest/gradle, `lib/` (14 file, ±2.700 baris), `test/`. Tidak ada build/install dijalankan. Detail UI di `form_*`, `list_*`, `detail_asset_page.dart`, `report_page.dart` hanya dibaca sebagian (grep) → bagian terkait ditandai "tidak terverifikasi".

## 1. Stack & struktur
- Flutter, Dart SDK `^3.10.4`, app v1.0.0+1 di `pubspec.yaml` (UI menulis "Versi 1.1.0" di `lib/settings_page.dart` → versi tidak sinkron).
- Paket: sqflite ^2.3, sqflite_common_ffi ^2.3 (desktop), provider ^6.0.5 (**terpasang, tidak terlihat dipakai** — tidak terverifikasi penuh), intl ^0.18, fl_chart ^0.63, pdf ^3.10 + printing ^5.11, csv ^5, share_plus ^7.1 (tidak terlihat dipakai), image_picker, path_provider, shared_preferences, google_fonts (tidak terlihat dipakai), file_selector.
- Struktur: repo git berada satu level di atas; app ada di `ternak_cibeusi_app/ternak_cibeusi_app/`. Semua kode di `lib/` datar (tanpa folder fitur) kecuali `lib/database/database_helper.dart`. Tidak ada layer service/repository/state management. Folder `build/` di-ignore (OK).
- Platform: android, ios, web, windows, linux, macos di-scaffold; DB ffi dipakai di desktop.

## 2. Fitur yang ada
- Splash + onboarding + simpan nama pemilik (`splash_page.dart`, `onboarding_page.dart`, SharedPreferences `owner_name`).
- Dashboard ringkasan: total ternak, saldo kas, masuk/keluar, grafik fl_chart (`main.dart`).
- CRUD aset: Ternak/Barang/Aset Tetap, foto, kondisi, satuan, tanggal kedaluwarsa, pemakaian, status kepemilikan & fungsi lahan (`form_asset_page.dart`, `list_asset_page.dart`, `detail_asset_page.dart`).
- CRUD transaksi IN/OUT dengan qty × harga satuan, 6 kategori masuk & 14 keluar (`form_finance_page.dart`, `list_finance_page.dart`, `finance_page.dart`).
- Laporan Laba Rugi, Neraca, ekspor PDF (`report_page.dart`).
- Backup CSV, Tutup Buku, Reset total (`settings_page.dart`).

## 3. Alur data
- **Penyimpanan 100% lokal**: SQLite `sikaya_platinum_combo_v1.db` (`database_helper.dart:20`), SharedPreferences untuk nama. Tidak ada cloud, sinkronisasi, maupun auth/login (tidak ada izin INTERNET di `android/app/src/main/AndroidManifest.xml`; tidak ada paket HTTP/Firebase/Supabase).
- Akses DB langsung dari widget via singleton `DatabaseHelper.instance` (`form_finance_page.dart:77`, `form_asset_page.dart:168`, `report_page.dart:20`). Tidak ada lapisan state; tiap halaman memanggil `setState` setelah load.
- Laporan dihitung ulang dari seluruh tabel `transactions` setiap dibuka (full scan di Dart, `getTransactions()` dipanggil berkali-kali per laporan).
- Backup hanya ekspor CSV satu arah; **tidak ada restore/import** (`settings_page.dart:35-47`).

## 4. Model data
- `AssetModel` (`lib/asset_model.dart`) → tabel `assets`: id, name, category, description, quantity, imagePath, date, condition, unit, expired_date, usage_ternak, usage_days, ownership_status, land_function. Satu tabel untuk tiga jenis aset berbeda; kolom opsional bercampur; `land_function` berupa string dipisah koma.
- `TransactionModel` (`lib/transaction_model.dart`) → tabel `transactions`: id, type(IN/OUT), amount, category, description, date(TEXT), qty, price. `date` disimpan sebagai TEXT `yyyy-MM-dd`.
- **Tidak ada**: entitas peternak/pengguna, kandang/batch/populasi, hewan individual, lahan/tanaman/panen, pemasok/pelanggan, utang-piutang sebagai entitas. Tidak ada foreign key; transaksi tidak terhubung ke aset.
- Semantik transaksi ditentukan oleh **string kategori** (daftar di `form_finance_page.dart:27-28`), bukan enum/kolom tipe akun.

## 5. Kualitas
- **Test**: hanya `test/widget_test.dart` = template counter bawaan Flutter, dan akan gagal (app tidak punya counter, `MyApp` memuat `SplashPage`). Nol test untuk logika akuntansi.
- **Lint**: `analysis_options.yaml` hanya `flutter_lints` default, tanpa aturan tambahan. Hasil `flutter analyze` tidak terverifikasi (tidak dijalankan). Terlihat: `Key? key` gaya lama, `withOpacity` (deprecated), `if/else` tanpa kurung (`database_helper.dart:77-78`).
- **Error handling**: hanya 8 `try/catch` di seluruh `lib/`. Operasi DB di `database_helper.dart` tanpa try/catch; `_saveTransaction` tidak menangani gagal simpan. `TransactionModel.fromMap` bisa melempar jika `amount` null (`transaction_model.dart:41`). Penggunaan `context` setelah `await` tanpa cek `mounted` di sejumlah tempat (mis. `settings_page.dart:36-37`).
- **Duplikasi/keterbacaan**: `settings_page.dart` memadatkan banyak statement dalam satu baris; warna/gaya diulang per file (`polbanBlue` didefinisikan ulang di banyak halaman); `getLabaRugiDetail`, `getNeracaDetail`, `getSaldoCashflow` masing-masing memuat ulang semua transaksi.
- Migrasi DB: `openDatabase(version: 1)` tanpa `onUpgrade` (`database_helper.dart:32`); perubahan skema berikutnya = data pengguna hilang/crash.

## 6. Risiko
- **Secret/key di repo**: tidak ditemukan (tidak ada `.env`, keystore, `key.properties` ter-track; `.gitignore` memuat `key.properties`). File `*.db` tidak ter-track. Aman pada cakupan ini.
- **Rilis Android**: `applicationId = com.example.ternak_cibeusi_app` dan `signingConfig = debug` untuk release (`android/app/build.gradle.kts:24,37`) → tidak layak Play Store.
- **Data finansial**: tanpa enkripsi DB, tanpa PIN/biometrik, tanpa backup yang bisa dipulihkan. Kehilangan HP = kehilangan seluruh pembukuan. "Reset Aplikasi" dan "Tutup Buku" menghapus data tanpa backup otomatis sebelumnya (`settings_page.dart:52-58`).
- **Offline**: sepenuhnya offline-first (kelebihan); namun tidak ada cadangan eksternal otomatis.
- Foto aset disimpan sebagai path dari image_picker (`imagePath`); tidak terverifikasi apakah file disalin ke direktori app → foto bisa hilang jika cache dibersihkan.
- Teks UI "Polban Edition" dan nama `polbanBlue`/`polbanOrange` → branding kampus tertanam; periksa hak pakai bila dirilis umum.

## 7. Utang teknis & bug (urut berat)
1. **Laba Rugi salah/ganda** (`database_helper.dart:93-123`, kategori di `form_finance_page.dart:27-28`):
   - "Beli Pakan Tunai" (OUT) mengandung "Pakan" → masuk `expPakan`; "Pemakaian Pakan (Stok)" juga → biaya pakan **dihitung dua kali** (beli + pakai). Sama untuk Obat.
   - "Beli Ternak/DOC" tidak mengandung "Biaya DOC" → masuk `expLain`, lalu "Biaya DOC (HPP)" dihitung lagi → ganda.
   - "Beli Perlengkapan/Peralatan Kandang", "Bayar Utang / Cicilan", "Prive" → semuanya jatuh ke `expLain` (belanja modal, pokok utang, dan penarikan pribadi dianggap biaya).
   - "Setor Modal Pribadi", "Terima Pinjaman (Utang)", "Terima Pelunasan Piutang" (IN) → jatuh ke `revLain` (modal/utang/pelunasan dianggap pendapatan).
   - "Jual … Kredit" masuk pendapatan (benar secara akrual) tetapi logikanya bergantung substring "Jual".
   Dampak: laba bersih dan modal akhir tidak bisa dipercaya.
2. **Neraca kemungkinan tidak seimbang** (`database_helper.dart:126-185`): `kas` dari cashflow tunai, persediaan/piutang dari substring, `peralatan` tidak pernah disusutkan/dikurangi, `bank` hardcode 0, `modalAkhir` memakai laba bernilai salah (butir 1). Tidak ada pengecekan Aktiva = Pasiva. Tidak terverifikasi di `report_page.dart` apakah selisih ditampilkan.
3. **Kas**: `getSaldoCashflow` mengecualikan kategori yang mengandung "Kredit"/"Pemakaian"/"Biaya DOC" via string (`:60-63`). Mengganti nama kategori mengubah angka diam-diam.
4. **"Tutup Buku" menipu**: dialog menyatakan "saldo jadi modal awal", tetapi `closeBookAndReset` hanya `DELETE FROM transactions` (`database_helper.dart:221-224`, `settings_page.dart:50`). Tidak ada saldo pembuka, aset/piutang/utang hilang dari neraca. Risiko kehilangan data finansial.
5. **Test rusak** (`test/widget_test.dart`) dan tanpa test akuntansi.
6. **Tanpa migrasi DB** (`database_helper.dart:32`) dan nama DB bergaya "combo_v1".
7. Backup CSV tidak lengkap: tidak menyertakan `qty`, `price`, maupun tabel `assets` (`settings_page.dart:39-40`); tanpa restore. Path backup Android `getExternalStorageDirectory` (folder app-spesifik, hilang saat uninstall).
8. Parsing uang: input dibersihkan dengan `replaceAll(RegExp(r'[^0-9]'),'')` → desimal/koma hilang; `amount` disimpan REAL (float) untuk uang (`form_finance_page.dart:68-71`). Qty gagal parse → default 1 diam-diam.
9. `date` TEXT tanpa validasi/format konsisten (sorting `date DESC` bergantung format ISO).
10. Dependensi mati (provider, share_plus, google_fonts, file_selector — tidak terverifikasi), `intl ^0.18` lama; `printing` + `pdfium` menambah ukuran build.
11. `lib/` datar, logika bisnis di dalam `DatabaseHelper`, widget raksasa (`form_asset_page.dart` 374 baris) → sulit diuji.
12. `MyApp` memakai `primarySwatch`, font 'Roboto' tanpa aset (kosmetik).

## 8. Gap terhadap kebutuhan peternak/pekebun (dari kode)
- Dominan **ayam/DOC** (kata "DOC", "Panen", "Pakan"); "pekebun" nyaris tidak terdukung: tidak ada tanaman, musim tanam, luas/petak, hasil panen, pupuk/pestisida sebagai entitas (hanya `land_function` teks).
- Tidak ada **batch/siklus produksi**: populasi awal, mortalitas/deplesi, bobot, FCR, umur panen, HPP per batch. "Biaya DOC (HPP saat Panen)" harus diinput manual.
- Stok pakan/obat tidak berbasis kuantitas: persediaan dihitung dari **rupiah** transaksi kategori, bukan kg/dosis; `usage_ternak`/`usage_days`/`expired_date` pada aset tidak memicu pengingat (tidak ada notifikasi/`flutter_local_notifications`).
- Tidak ada pengingat vaksinasi/jadwal, kesehatan ternak, atau catatan penyakit.
- Tidak ada pelanggan/pemasok, utang-piutang per pihak, nota/struk, atau penyusutan aset tetap.
- Tidak ada multi-pengguna/karyawan, multi-peternakan, atau peran akses.
- Tidak ada impor data, restore, sinkron antar-perangkat, atau ekspor Excel; laporan terbatas Laba Rugi & Neraca (arus kas dan laporan per periode/bulan: tidak terverifikasi).
- Lokalisasi sudah Bahasa Indonesia (IDR, `id_ID`) — sesuai pengguna sasaran.

## Prioritas saran singkat
1. Perbaiki pemetaan kategori→akun (gunakan enum/kolom `account_type`) + unit test laba rugi/neraca.
2. Perbaiki "Tutup Buku" (saldo pembuka) dan wajibkan backup sebelum hapus.
3. Tambah migrasi DB, restore backup, signing release & applicationId sendiri.
