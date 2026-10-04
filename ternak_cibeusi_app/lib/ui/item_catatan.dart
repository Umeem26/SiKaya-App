// Satu baris catatan (transaksi), dipakai di Riwayat dan "Catatan terakhir" di
// Beranda. Arah uang selalu ditulis dengan kata dan tanda, bukan warna saja.
import 'package:flutter/material.dart';

import '../accounting/models.dart';
import '../accounting/tx_form_spec.dart' show labelTransaksi;
import '../transaction_model.dart';
import 'komponen.dart';
import 'theme.dart';
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

/// Ikon satu jenis kejadian (null = retur), dipakai di "Apa yang terjadi?" dan daftar catatan.
IconData ikonJenis(TxType? t) => switch (t) {
      null => Icons.undo_rounded,
      TxType.penjualanTunai => Icons.sell_rounded,
      TxType.penjualanKredit => Icons.request_quote_rounded,
      TxType.terimaPiutang => Icons.payments_rounded,
      TxType.beliPersediaanTunai => Icons.shopping_cart_rounded,
      TxType.beliPersediaanKredit => Icons.add_shopping_cart_rounded,
      TxType.beliAsetTetap => Icons.warehouse_rounded,
      TxType.pakaiPersediaan => Icons.grass_rounded,
      TxType.kematianTernak => Icons.heart_broken_rounded,
      TxType.bebanOperasional => Icons.receipt_long_rounded,
      TxType.bebanBunga => Icons.percent_rounded,
      TxType.setorModal => Icons.savings_rounded,
      TxType.prive => Icons.account_balance_wallet_rounded,
      TxType.terimaPinjaman => Icons.account_balance_rounded,
      TxType.bayarCicilanPokok => Icons.credit_card_rounded,
      TxType.penyusutan => Icons.trending_down_rounded,
      TxType.tutupBuku => Icons.lock_clock_rounded,
    };

/// Warna ubin per arah kas: masuk hijau, keluar oranye tua, tidak lewat kas biru.
Nada nadaArah(int arahKas) => arahKas > 0 ? Nada.sukses : (arahKas < 0 ? Nada.peringatan : Nada.netral);

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
    final nilai = nilaiCatatan(c);
    final rincian = [
      tanggalPendek(c.date),
      if (c.qty != null && c.qty! > 0) '${c.qty} ${satuanBarang(c.item)}'.trim(),
    ].join(' · ');
    final gayaNilai = gayaAngka((nilai == null ? t.bodySmall : t.titleSmall)!
        .copyWith(color: warna, fontWeight: FontWeight.w700));
    final kolomNilai = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(nilai ?? 'Nilai dihitung otomatis', textAlign: TextAlign.right, style: gayaNilai),
      Text(kataArah(c), style: t.bodySmall!.copyWith(color: warna, fontWeight: FontWeight.w600)),
    ]);
    final judul = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(labelTransaksi(c), style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(rincian, style: gayaAngka(t.bodySmall!.copyWith(color: Warna.teksSekunder))),
    ]);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(Jarak.s12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              UbinIkon(ikonJenis(c.reversalOf != null ? null : c.txType), nada: nadaArah(arah)),
              const SizedBox(width: Jarak.s12),
              Expanded(
                // Nominal rata kanan di samping judul bila muat; bila huruf besar,
                // turun ke bawah judul (tetap rata kanan, satu baris).
                child: LayoutBuilder(builder: (context, k) {
                  final ukur = TextPainter(
                    text: TextSpan(text: nilai ?? 'Nilai dihitung otomatis', style: gayaNilai),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 1,
                  )..layout();
                  final lebarNilai = ukur.width;
                  ukur.dispose();
                  final samping = lebarNilai + Jarak.s12 <= k.maxWidth * 0.5;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (samping)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: judul),
                        const SizedBox(width: Jarak.s12),
                        kolomNilai,
                      ])
                    else ...[
                      judul,
                      const SizedBox(height: Jarak.s4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          TeksUang(nilai ?? 'Nilai dihitung otomatis', gaya: gayaNilai, kanan: true),
                          Text(kataArah(c),
                              style: t.bodySmall!.copyWith(color: warna, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                    if (c.perluDitinjau) ...[
                      const SizedBox(height: Jarak.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Jarak.s8, vertical: Jarak.s4),
                        decoration: BoxDecoration(
                          color: Warna.peringatanMuda,
                          borderRadius: BorderRadius.circular(Sudut.kecil),
                        ),
                        child: Text('Perlu dicek: ${alasanPerluDicek(c.reviewNote)}',
                            style: t.bodySmall!.copyWith(color: Warna.peringatan, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]);
                }),
              ),
              if (onTap != null) ...[
                const SizedBox(width: Jarak.s4),
                const Padding(
                  padding: EdgeInsets.only(top: Jarak.s8),
                  child: Icon(Icons.chevron_right_rounded, color: Warna.teksSekunder),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
