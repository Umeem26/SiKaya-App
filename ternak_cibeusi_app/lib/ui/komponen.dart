// Komponen bersama SiKaya (UI-PLAN.md bagian 4). Aturan: area sentuh >= 48dp,
// ikon selalu disertai tulisan, tidak ada ukuran huruf tetap (pakai TextTheme),
// tidak ada Row kaku yang bisa overflow saat huruf diperbesar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'tokens.dart';

// --- Tombol ---

enum _JenisTombol { utama, kedua, bahaya }

class _Tombol extends StatelessWidget {
  const _Tombol(this.jenis,
      {required this.label, required this.ikon, this.onPressed, required this.lebarPenuh});
  final _JenisTombol jenis;
  final bool lebarPenuh;
  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final teks = Text(label, textAlign: TextAlign.center);
    final ikonW = Icon(ikon);
    Size min(double h) => lebarPenuh ? Size.fromHeight(h) : Size(tinggiSentuh, h);
    return switch (jenis) {
      _JenisTombol.utama => FilledButton.icon(
          onPressed: onPressed,
          icon: ikonW,
          label: teks,
          style: FilledButton.styleFrom(minimumSize: min(tinggiTombolUtama)),
        ),
      _JenisTombol.kedua => OutlinedButton.icon(
          onPressed: onPressed,
          icon: ikonW,
          label: teks,
          style: OutlinedButton.styleFrom(minimumSize: min(tinggiSentuh)),
        ),
      _JenisTombol.bahaya => FilledButton.icon(
          onPressed: onPressed,
          icon: ikonW,
          label: teks,
          style: FilledButton.styleFrom(
            minimumSize: min(tinggiSentuh),
            backgroundColor: Warna.error,
            foregroundColor: Warna.putih,
          ),
        ),
    };
  }
}

/// Aksi utama layar: lebar penuh, tinggi 56dp, ikon + tulisan.
class TombolUtama extends StatelessWidget {
  const TombolUtama(
      {super.key, required this.label, required this.ikon, this.onPressed, this.lebarPenuh = true});
  final bool lebarPenuh;
  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      _Tombol(_JenisTombol.utama, label: label, ikon: ikon, onPressed: onPressed, lebarPenuh: lebarPenuh);
}

/// Aksi pendamping (Batal, Lihat): garis tepi, tinggi 48dp.
class TombolKedua extends StatelessWidget {
  const TombolKedua(
      {super.key, required this.label, required this.ikon, this.onPressed, this.lebarPenuh = true});
  final bool lebarPenuh;
  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      _Tombol(_JenisTombol.kedua, label: label, ikon: ikon, onPressed: onPressed, lebarPenuh: lebarPenuh);
}

/// Aksi yang menghapus/mengganti data: merah, tinggi 48dp.
class TombolBahaya extends StatelessWidget {
  const TombolBahaya(
      {super.key, required this.label, required this.ikon, this.onPressed, this.lebarPenuh = true});
  final bool lebarPenuh;
  final String label;
  final IconData ikon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      _Tombol(_JenisTombol.bahaya, label: label, ikon: ikon, onPressed: onPressed, lebarPenuh: lebarPenuh);
}

// --- Kartu ---

enum Nada { netral, sukses, peringatan, error }

({Color isi, Color latar}) warnaNada(Nada n) => switch (n) {
      Nada.netral => (isi: Warna.primer, latar: Warna.primerMuda),
      Nada.sukses => (isi: Warna.sukses, latar: Warna.suksesMuda),
      Nada.peringatan => (isi: Warna.peringatan, latar: Warna.peringatanMuda),
      Nada.error => (isi: Warna.error, latar: Warna.errorMuda),
    };

/// Satu angka penting: judul, nilai besar, kalimat keterangan. Arti tidak hanya
/// lewat warna: [judul] dan [nilai] sudah memuat kata/tanda (+, −, Untung, Rugi).
class KartuAngka extends StatelessWidget {
  const KartuAngka({
    super.key,
    required this.judul,
    required this.nilai,
    required this.ikon,
    this.keterangan,
    this.nada = Nada.netral,
  });
  final String judul;
  final String nilai;
  final IconData ikon;
  final String? keterangan;
  final Nada nada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = warnaNada(nada);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(ikon, color: w.isi, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(judul, style: t.titleSmall)),
            ]),
            const SizedBox(height: 8),
            Text(nilai, style: t.headlineSmall!.copyWith(color: w.isi)),
            if (keterangan != null) ...[
              const SizedBox(height: 4),
              Text(keterangan!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pesan penting di atas isi layar (perlu ditinjau, tidak seimbang, terkunci),
/// dengan aksi opsional berlabel.
class BannerPeringatan extends StatelessWidget {
  const BannerPeringatan({
    super.key,
    required this.judul,
    required this.isi,
    this.nada = Nada.peringatan,
    this.aksi,
    this.ikonAksi = Icons.arrow_forward,
    this.onAksi,
  });
  final String judul;
  final String isi;
  final Nada nada;
  final String? aksi;
  final IconData ikonAksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = warnaNada(nada);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: w.latar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: w.isi, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: w.isi, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(judul, style: t.titleSmall!.copyWith(color: w.isi))),
          ]),
          const SizedBox(height: 8),
          Text(isi, style: t.bodyLarge),
          if (aksi != null) ...[
            const SizedBox(height: 12),
            TombolKedua(label: aksi!, ikon: ikonAksi, onPressed: onAksi),
          ],
        ],
      ),
    );
  }
}

// --- Input Rupiah ---

final _ribuan = NumberFormat.decimalPattern('id_ID');

/// "Rp12.500.000" / "−Rp12.500" (bilangan bulat Rupiah, tanpa desimal).
String rupiah(int v) => '${v < 0 ? '−' : ''}Rp${_ribuan.format(v.abs())}';

/// Dengan tanda arah: "+Rp5.000" (bertambah), "−Rp5.000" (berkurang), "Rp0".
String bertanda(int v) => v > 0 ? '+${rupiah(v)}' : rupiah(v);

/// Pemisah ribuan (titik) untuk bilangan bulat Rupiah, tanpa double.
class RibuanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _ribuan.format(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Bilangan bulat dari teks berformat ribuan ("12.500" -> 12500); null bila kosong.
int? bacaRupiah(String s) => int.tryParse(s.replaceAll('.', ''));

/// Input nominal Rupiah: angka besar, keyboard angka, titik ribuan, maks 15 digit.
class InputRupiah extends StatelessWidget {
  const InputRupiah({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<int?>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      style: t.titleMedium,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
        RibuanFormatter(),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        prefixStyle: t.titleMedium,
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      onChanged: onChanged == null ? null : (s) => onChanged!(bacaRupiah(s)),
    );
  }
}

// --- Dialog konfirmasi ---

/// Dialog ya/tidak. [isi] menyebut akibatnya; [aksi] berupa kata kerja ("Hapus",
/// "Pulihkan"), bukan "OK". true hanya bila pengguna menekan [aksi].
Future<bool> tanyaKonfirmasi(
  BuildContext context, {
  required String judul,
  required String isi,
  required String aksi,
  required IconData ikonAksi,
  bool bahaya = false,
  String batal = 'Batal',
}) async {
  final ya = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: SingleChildScrollView(child: Text(isi)),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TombolKedua(
            label: batal, ikon: Icons.close, lebarPenuh: false, onPressed: () => Navigator.pop(ctx, false)),
        if (bahaya)
          TombolBahaya(
              label: aksi, ikon: ikonAksi, lebarPenuh: false, onPressed: () => Navigator.pop(ctx, true))
        else
          TombolUtama(
              label: aksi, ikon: ikonAksi, lebarPenuh: false, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return ya ?? false;
}
