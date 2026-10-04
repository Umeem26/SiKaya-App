# ACCOUNTING-SPEC: SiKaya mengacu SAK EMKM

Dokumen ini adalah satu-satunya acuan perhitungan untuk Fase 1. Claude Code membaca file ini, tidak perlu mencari aturan lain.

## Status sumber (WAJIB dibaca)
- Standar acuan: SAK EMKM (IAI). Disahkan 24 Okt 2016; halaman resmi IAI menyatakan belum ada revisi (dicek 3 Okt 2026).
- Isi aturan di bawah diambil dari **draft eksposur (ED)** SAK EMKM, bukan teks final. Nomor paragraf dan redaksi bisa berbeda.
  TODO pemilik: cocokkan dengan teks final di sak.iaiglobal.or.id sebelum rilis.
- SAK EMKM TIDAK mengatur aset biologis (ternak/tanaman). Bagian itu = kebijakan akuntansi SiKaya (lihat B7), harus diungkap di CaLK.
- Hasil akhir sebaiknya ditinjau satu kali oleh dosen akuntansi atau praktisi.

## A. Laporan yang dihasilkan (minimal menurut SAK EMKM)
1. Laporan Posisi Keuangan (di UI lama: "Neraca")
2. Laporan Laba Rugi
3. Catatan atas Laporan Keuangan (CaLK): dihasilkan otomatis, berisi dasar penyusunan, metode persediaan, metode penyusutan, kebijakan aset biologis (B7), ikhtisar akun penting.
Istilah di laporan formal: "Beban" (bukan "biaya"), "Pendapatan", "Saldo Laba". UI sehari-hari boleh memakai bahasa petani, laporan formal tidak.

## B. Aturan pengakuan
B1. Persediaan (pakan, obat, DOC): dicatat sebesar harga perolehan (semua biaya pembelian). Saat DIBELI jadi aset Persediaan, BUKAN beban. Menjadi beban ketika dipakai/terjual (pada periode yang sama dengan pengakuan pendapatan). Metode: rata-rata tertimbang (disarankan, lebih sederhana) atau FIFO; pilih satu, ungkap di CaLK.
B2. Aset tetap (kandang, peralatan, kendaraan): dicatat pada harga perolehan, bukan beban saat dibeli. Disusutkan: garis lurus atau saldo menurun, **tanpa nilai residu**. Tanah tidak disusutkan. Penyusutan mulai saat siap dipakai.
B3. Pendapatan: diakui saat ada hak atas pembayaran (barang/jasa sudah diserahkan). Uang muka dari pembeli = liabilitas. Penjualan belum dibayar = piutang.
B4. Liabilitas: sebesar jumlah yang harus dibayar. Pokok pinjaman BUKAN pendapatan. Cicilan pokok BUKAN beban; bunga = beban.
B5. Ekuitas = Modal disetor + Saldo Laba. Setoran modal BUKAN pendapatan. Prive (penarikan pemilik) mengurangi ekuitas, BUKAN beban.
B6. Saldo Laba = akumulasi (pendapatan - beban) dikurangi distribusi ke pemilik.
B7. Aset biologis (kebijakan SiKaya, bukan dari SAK EMKM, **butuh keputusan pemilik + review akuntan**): DOC/bibit dan pakan yang dikonsumsi ternak dikumpulkan sebagai Persediaan/Aset Ternak sebesar biaya perolehan, lalu dipindah ke Beban Pokok Penjualan saat ternak terjual atau panen. Kematian ternak di luar kewajaran = Beban kerugian ternak.

## C. Tipe transaksi eksplisit (ganti pencocokan substring nama kategori)
| Tipe | Debit | Kredit | Pengaruh Laba Rugi |
|---|---|---|---|
| penjualan_tunai | Kas | Pendapatan | + |
| penjualan_kredit | Piutang | Pendapatan | + |
| terima_piutang | Kas | Piutang | 0 |
| beli_persediaan_tunai | Persediaan | Kas | 0 |
| beli_persediaan_kredit | Persediaan | Utang usaha | 0 |
| pakai_persediaan | Beban (pakan/obat/BPP) | Persediaan | - |
| beban_operasional | Beban | Kas/Utang | - |
| beli_aset_tetap | Aset tetap | Kas/Utang | 0 |
| penyusutan | Beban penyusutan | Akumulasi penyusutan | - |
| setor_modal | Kas | Modal | 0 |
| prive | Prive (kontra-ekuitas) | Kas | 0 |
| terima_pinjaman | Kas | Utang | 0 |
| bayar_cicilan_pokok | Utang | Kas | 0 |
| beban_bunga | Beban bunga | Kas | - |
| kematian_ternak | Beban kerugian ternak (qty mati × biaya rata-rata tertimbang) | Persediaan ternak | - (kebijakan B7, bukan SAK EMKM) |
| tutup_buku | Laba/rugi periode | Saldo Laba | arsip, tidak hapus |

## D. Invarian yang WAJIB dites (laporan, bukan hanya fungsi hitung)
1. Total Aset = Total Liabilitas + Ekuitas, di setiap tanggal laporan. Kalau tidak seimbang, tampilkan peringatan, bukan angka diam-diam.
2. Laba bersih = Pendapatan - Beban, dan angka ini sama persis di Laporan Laba Rugi dan di perubahan Saldo Laba.
3. Saldo Kas di laporan = saldo kas dari buku kas.
4. Tidak ada transaksi yang masuk Laba Rugi dan Posisi Keuangan sekaligus dengan cara yang menghitung dua kali.
5. Tutup Buku: tidak ada transaksi yang terhapus; total Aset sebelum dan sesudah sama.

## E. Skenario uji dengan jawaban hitung manual
1. Beli pakan Rp1.000.000 tunai, pakai Rp400.000: Beban pakan 400.000; Persediaan 600.000; Laba -400.000.
2. Setor modal Rp5.000.000: Kas +5.000.000; Laba tetap 0.
3. Pinjam Rp2.000.000, bayar cicilan pokok Rp500.000: Utang 1.500.000; Laba 0.
4. Prive Rp300.000: Ekuitas -300.000; Laba 0.
5. Beli peralatan Rp1.200.000 (umur 12 bulan, garis lurus): Laba tidak berubah saat beli; beban penyusutan Rp100.000/bulan.
6. Jual ayam Rp3.000.000 kredit, lalu terima Rp3.000.000: Pendapatan 3.000.000 pada penjualan; saat pelunasan Laba tidak bertambah lagi.
7. Skenario campuran 1-6: cek semua invarian D.
