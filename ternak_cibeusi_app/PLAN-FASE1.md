# PLAN FASE 1 — Akuntansi SiKaya mengacu SAK EMKM

Acuan: `ACCOUNTING-SPEC-SAK-EMKM.md` (bagian A-E) dan `AUDIT-SIKAYA.md`. Dokumen ini hanya rencana; belum ada kode diubah.

## 1. Keputusan (Langkah 0)
| Hal | Keputusan |
|---|---|
| Persediaan | Rata-rata tertimbang |
| Penyusutan | Garis lurus, tanpa nilai residu. Umur manfaat bisa diedit per aset. Nilai awal 4/10/8 tahun (peralatan kecil/kandang semi permanen/kendaraan) hanya titik awal, belum diverifikasi. Ungkap di CaLK |
| Aset biologis (B7) | Disetujui sementara, tampil di CaLK sebagai "kebijakan manajemen". Perlu tinjauan akuntan/dosen sebelum diklaim ke publik |
| Data lama | Dibuang (belum ada data riil petani) |
| Teks final SAK EMKM | Dicocokkan pemilik di sak.iaiglobal.or.id, fokus persediaan, aset tetap, ekuitas |

Diputuskan kemudian:
- **Aturan penyusutan:** mulai bulan "tanggal siap dipakai" (default = tanggal beli), bulan penuh, berhenti saat akumulasi = harga perolehan, sisa pembulatan di bulan terakhir. Ditulis di CaLK.
- **Tabel kasus tepi (bagian 4) disetujui**, dengan syarat tiap kasus memuat angka hitung manual (sudah ditambahkan).

**Status:** tahap 1 dan 3 (mesin) selesai. Tahap 2 selesai: DB v2 (`lib/database/schema.dart`, backup otomatis file v1), repository `lib/accounting/repository.dart`, laporan/dashboard membaca dari repository. Tahap 4 selesai: tutup buku non-destruktif (`AccountingRepository.closeBook`, backup file DB, `period_closings`, kunci periode; tes `test/accounting/closing_test.dart`). Tahap 5: form per tipe transaksi dari tabel `lib/accounting/tx_form_spec.dart` (tes `tx_form_spec_test.dart`), pilihan periode laporan; uji manual di perangkat belum.

## 2. Prinsip desain
1. **Uang = bilangan bulat Rupiah** (`INTEGER`), bukan `double`. Sekarang `amount`/`price` bertipe REAL di `lib/database/database_helper.dart` dan `lib/transaction_model.dart`.
   - Rata-rata tertimbang dihitung dari total nilai (integer) dan total kuantitas: biaya pakai = `round(nilai_total × qty_pakai / qty_total)`; nilai sisa = nilai_total − biaya pakai.
   - Penyusutan: bulan terakhir mengambil sisa, sehingga total penyusutan seluruh umur = harga perolehan tepat.
2. **Penyusutan dihitung saat laporan dibuat** dari harga perolehan, tanggal, umur manfaat. Tidak ada tabel `depreciation_entries`. Laporan tanggal mana pun bisa direproduksi.
   - Aset yang sudah dipakai di periode terkunci: harga/umur tidak boleh diedit. Perubahan umur lewat catatan baru yang berlaku ke depan.
3. **Fungsi laporan murni:** input `List` transaksi + aset (+ tanggal laporan), output laporan. Tanpa SQLite, agar bisa dites.
4. **Tipe transaksi eksplisit** (enum `TxType`, 15 tipe pada spec bagian C), bukan pencocokan substring nama kategori. Kategori hanya label rincian beban.
5. Baris yang tidak valid/ambigu diberi status `perlu_ditinjau`: dikeluarkan dari laporan, ditampilkan sebagai peringatan beserta hitungannya, diputuskan pemilik/admin.

## 3. Tahapan
| Tahap | Isi | Selesai jika |
|---|---|---|
| 1 | Tes dulu: 7 skenario E, 5 invarian D, tes pembulatan/penyusutan, kasus tepi. Ganti `test/widget_test.dart` yang rusak | Semua tertulis; sebagian gagal terhadap logika lama (membuktikan bug audit) |
| 2 | Skema v2: `tx_type`, uang INTEGER, status `perlu_ditinjau`, tabel `period_closings`. Karena data dibuang, tabel dibuat ulang; `onUpgrade` ditulis untuk v2 dan seterusnya | DB v2 jalan di Android dan Windows |
| 3 | Mesin laporan: persediaan rata-rata tertimbang, penyusutan on-the-fly, Laba Rugi, Posisi Keuangan, Saldo Laba, CaLK, peringatan tidak seimbang | Tes skenario E dan invarian D hijau |
| 4 | Tutup buku non-destruktif (entri `tutup_buku` ke Saldo Laba, periode terkunci, tidak ada transaksi dihapus) + backup otomatis sebelum tutup buku dan reset | Tes D5 hijau |
| 5 | UI minimal fungsional: form memilih tipe, halaman laporan menampilkan tiga laporan, peringatan tidak seimbang. Ekspor PDF dipertahankan seadanya | Uji manual |

Di luar Fase 1 (Fase 3 dan seterusnya): palet/logo, tombol "apa yang terjadi?", PDF rapi, backup/restore lengkap, signing dan `applicationId`, batch/populasi, modul pekebun.

### Hasil tahap 1
- Dibuat: `lib/accounting/models.dart` (enum 16 tipe, `AcctTx`, `FixedAsset`, `Report`), `lib/accounting/engine.dart` (stub `UnimplementedError`), `test/accounting/` (4 file tes + helper), 35 tes.
- `test/widget_test.dart` (template counter yang rusak) dihapus. Logika lama (`DatabaseHelper`, halaman UI) tidak diubah.
- Status saat ini: 1 tes lulus (daftar tipe), 34 gagal dengan `UnimplementedError`. Tes tidak dijalankan terhadap logika lama, jadi bug laba rugi ganda dari audit belum "dibuktikan" lewat tes; hanya tertulis sebagai angka manual yang benar.

## 4. Kasus tepi (disetujui) dengan angka hitung manual
| Kasus | Perilaku | Angka manual |
|---|---|---|
| K1 Retur | Transaksi pembalik (`reversalOf` = id asli, tipe sama); yang asli tidak diedit/dihapus. Retur > nilai asli → `perlu_ditinjau`, dikeluarkan | Jual tunai 1.000.000, retur 200.000 → pendapatan 800.000, kas 800.000. Retur 1.000.001 → ditandai, pendapatan tetap 1.000.000 |
| K2 Pembayaran sebagian | `terima_piutang` merujuk penjualan kredit (`refId`); boleh kurang dari sisa. Lebih dari sisa → `perlu_ditinjau`, dikeluarkan | Piutang 3.000.000: terima 1.000.000 → piutang 2.000.000, kas 1.000.000; terima 2.000.000 lagi → piutang 0, kas 3.000.000, laba 3.000.000 (tidak bertambah). Terima 3.000.001 → ditandai, piutang tetap 3.000.000 |
| K3 Kematian ternak | Tipe `kematian_ternak`: beban kerugian ternak = nilai rata-rata tertimbang, mengurangi persediaan ternak (B7) | 100 ekor @10.000 + 100 ekor @12.000 = 2.200.000 / 200 ekor = 11.000/ekor. Mati 4 → kerugian 44.000; persediaan ternak 2.156.000; laba −44.000 |
| K4 Pemakaian > stok | Transaksi diterima/disimpan, ditandai `perlu_ditinjau`, **dikeluarkan dari laporan** (beban tidak diakui, stok tidak minus); peringatan memuat id, qty diminta, qty tersedia | Stok pakan 100 kg Rp1.000.000, pakai 120 kg → beban 0, persediaan 1.000.000, 1 peringatan (120 vs 100) |
| K5 Periode terkunci | Insert/edit/hapus pada tanggal ≤ tanggal kunci ditolak (`PeriodLockedException`); edit yang memindahkan tanggal dari/ke periode terkunci juga ditolak | Kunci 2026-01-31: tulis 2026-01-31 ditolak, 2026-02-01 diterima. Laporan Jan tetap laba 2.500.000, total aset 8.700.000 |
| K6 Urutan hari yang sama | Diproses menurut `id` naik, bukan urutan list | id10 beli 100 kg 1.000.000; id11 beli 100 kg 2.000.000; id12 pakai 100 kg (tanggal sama): 3.000.000/200 kg × 100 = beban 1.500.000, sisa 1.500.000. Pakai id9 sebelum beli id10 → melebihi stok, ditandai |
| K7 Penjualan tanggal lampau | Boleh bila periode belum terkunci; laporan tanggal lampau dihitung ulang | Skenario campuran + jual tunai 500.000 bertanggal 2026-01-05: pendapatan Jan 3.500.000, laba 3.000.000, kas 7.500.000; per 2026-01-05 pendapatan 500.000 |

Pembulatan rata-rata tertimbang dan penyusutan: setengah menjauhi nol (simetris: −0,5 → −1), sehingga transaksi dan pembaliknya saling meniadakan tepat. Contoh 3 unit Rp1.000 dipakai 1+1+1 → 333 + 334 + 333 = 1.000 (sisa persediaan 0).

Catatan: pada rata-rata tertimbang, pembelian/pemakaian bertanggal lampau mengubah biaya rata-rata pemakaian sesudahnya. Karena itu hanya diizinkan untuk periode yang belum terkunci. Retur barang yang kembali ke stok (persediaan bertambah lagi) belum dicakup di Fase 1.

Catatan: pada rata-rata tertimbang, pembelian/pemakaian bertanggal lampau mengubah biaya rata-rata pemakaian sesudahnya. Karena itu hanya diizinkan untuk periode yang belum terkunci.

## 5. Risiko
- B7 bukan bagian SAK EMKM; hasil akhir perlu ditinjau sekali oleh dosen/praktisi.
- Spec memakai draf eksposur, bukan teks final.
- 7 skenario E belum mencakup semua kasus nyata; kasus tepi bagian 4 harus ditambahkan sebelum rilis.
