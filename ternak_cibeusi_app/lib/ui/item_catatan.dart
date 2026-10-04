// Satu baris catatan (transaksi), dipakai di Riwayat dan "Catatan terakhir" di
// Beranda. Arah uang selalu ditulis dengan kata dan tanda, bukan warna saja.
import 'package:flutter/material.dart';

import '../accounting/models.dart';
import '../accounting/tx_form_spec.dart' show labelTransaksi;
import '../transaction_model.dart';
import 'komponen.dart';
import 'tokens.dart';

/// Kata arah kas: "Masuk" / "Keluar" / "Tidak lewat kas".
String kataArah(TransactionModel t) => switch (t.arahKas) {
      > 0 => 'Masuk',
      < 0 => 'Keluar',
      _ => 'Tidak lewat kas',
    };

/// Nilai bertanda sesuai arah kas: "+Rp500.000", "−Rp200.000", "Rp300.000".
/// Pemakaian stok dan ternak mati (nilai dihitung mesin) -> null.
String? nilaiCatatan(TransactionModel t) {
  if (t.amount == 0 && (t.txType == TxType.pakaiPersediaan || t.txType == TxType.kematianTernak)) {
    return null;
  }
  return switch (t.arahKas) {
    > 0 => bertanda(t.amount),
    < 0 => bertanda(-t.amount),
    _ => rupiah(t.amount),
  };
}

String satuanBarang(StockItem? i) => switch (i) {
      StockItem.pakan => 'kg',
      StockItem.obat => 'dosis',
      StockItem.ternak => 'ekor',
      null => '',
    };

String namaBarang(StockItem i) => switch (i) {
      StockItem.pakan => 'Pakan',
      StockItem.obat => 'Obat & vitamin',
      StockItem.ternak => 'Ternak / bibit',
    };

/// Alasan "perlu dicek" dalam bahasa petani, dari review_note "alasan: rincian".
String alasanPerluDicek(String? reviewNote) {
  final kode = reviewNote?.split(':').first.trim();
  return switch (kode) {
    'pemakaianMelebihiStok' => 'Jumlah yang dipakai melebihi stok yang tercatat',
    'pelunasanMelebihiPiutang' => 'Pembayaran melebihi sisa piutang',
    'returMelebihiAsli' => 'Retur melebihi nilai catatan asalnya',
    'referensiTidakDitemukan' => 'Catatan yang dirujuk tidak ditemukan',
    'dataTidakValid' => 'Isian catatan tidak lengkap atau tidak sah',
    _ => 'Catatan ini perlu diperiksa',
  };
}

class ItemCatatan extends StatelessWidget {
  const ItemCatatan({super.key, required this.catatan, this.onTap});
  final TransactionModel catatan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = catatan;
    final arah = c.arahKas;
    final warna = arah > 0 ? Warna.sukses : (arah < 0 ? Warna.teks : Warna.teksSekunder);
    final ikon = arah > 0 ? Icons.south_west : (arah < 0 ? Icons.north_east : Icons.swap_horiz);
    final nilai = nilaiCatatan(c);
    final rincian = [
      tanggalPendek(c.date),
      if (c.qty != null && c.qty! > 0) '${c.qty} ${satuanBarang(c.item)}'.trim(),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(ikon, color: warna, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(labelTransaksi(c), style: t.titleSmall),
                  Text(rincian, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(nilai ?? 'Nilai dihitung otomatis',
                        style: (nilai == null ? t.bodySmall : t.titleSmall)!.copyWith(color: warna)),
                    Text(kataArah(c), style: t.bodySmall!.copyWith(color: warna, fontWeight: FontWeight.w600)),
                  ]),
                  if (c.perluDitinjau) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Warna.peringatanMuda,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Warna.peringatan),
                      ),
                      child: Text('Perlu dicek: ${alasanPerluDicek(c.reviewNote)}',
                          style: t.bodySmall!.copyWith(color: Warna.peringatan, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: Warna.teksSekunder),
            ]),
          ),
        ),
      ),
    );
  }
}
