// Komponen bersama SiKaya (UI-PLAN.md bagian 4). Aturan: area sentuh >= 48dp,
// ikon selalu disertai tulisan, tidak ada ukuran huruf tetap (pakai TextTheme),
// tidak ada Row kaku yang bisa overflow saat huruf diperbesar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'tokens.dart';

/// Faktor ukuran ikon: ikut setelan huruf HP (dibatasi 1,5x) agar ikon tidak
/// tampak kecil di samping tulisan yang diperbesar.
double skalaIkon(BuildContext context) => MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

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
    final ikonW = Icon(ikon, size: 24 * skalaIkon(context));
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

/// Ikon di atas ubin bersudut berwarna muda (gaya UI lama): penanda jenis yang
/// cepat dikenali. Selalu dipakai bersama tulisan, tidak berdiri sendiri.
class UbinIkon extends StatelessWidget {
  const UbinIkon(this.ikon, {super.key, this.nada = Nada.netral, this.ukuran = 44, this.diAtasMerek = false});
  final IconData ikon;
  final Nada nada;
  final double ukuran;

  /// Di atas gradien merek: ubin putih transparan, ikon putih.
  final bool diAtasMerek;

  @override
  Widget build(BuildContext context) {
    final w = warnaNada(nada);
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        color: diAtasMerek ? const Color(0x29FFFFFF) : w.latar,
        borderRadius: BorderRadius.circular(Sudut.kecil),
      ),
      child: Icon(ikon, color: diAtasMerek ? Warna.putih : w.isi, size: ukuran * 0.55),
    );
  }
}

/// Label pil kecil (jumlah, kondisi, status): latar muda, tulisan tebal berwarna.
class ChipPil extends StatelessWidget {
  const ChipPil(this.label, {super.key, this.nada = Nada.netral, this.ikon});
  final String label;
  final Nada nada;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final w = warnaNada(nada);
    final gaya = gayaAngka(Theme.of(context).textTheme.labelMedium!.copyWith(color: w.isi));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Jarak.s12, vertical: Jarak.s4),
      // Sudut 14 (bukan pil penuh): tetap rapi bila tulisan turun dua baris.
      decoration: BoxDecoration(color: w.latar, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ikon != null) ...[
          Icon(ikon, size: 18 * skalaIkon(context), color: w.isi),
          const SizedBox(width: Jarak.s4),
        ],
        Flexible(child: Text(label, style: gaya)),
      ]),
    );
  }
}

/// Nominal satu baris: tidak pernah terbelah; bila tidak muat (huruf sangat
/// besar) mengecil. Figur tabular.
class TeksUang extends StatelessWidget {
  const TeksUang(this.nilai, {super.key, required this.gaya, this.kanan = false});
  final String nilai;
  final TextStyle gaya;
  final bool kanan;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: kanan ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Text(nilai,
            maxLines: 1, softWrap: false, textAlign: kanan ? TextAlign.right : null, style: gayaAngka(gaya)),
      );
}

/// Judul seksi di dalam layar (bukan judul layar), dengan aksi teks opsional.
/// Bila tidak muat sebaris (huruf besar), aksi turun ke baris berikutnya.
class JudulSeksi extends StatelessWidget {
  const JudulSeksi(this.judul, {super.key, this.aksi, this.ikonAksi = Icons.chevron_right_rounded, this.onAksi, this.warna});
  final String judul;
  final String? aksi;
  final IconData ikonAksi;
  final VoidCallback? onAksi;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Jarak.s8,
      children: [
        Semantics(header: true, child: Text(judul, style: t.titleMedium!.copyWith(color: warna))),
        if (aksi != null)
          TextButton(
            onPressed: onAksi,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Jarak.s8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(aksi!)),
              Icon(ikonAksi, size: 24 * skalaIkon(context)),
            ]),
          ),
      ],
    );
  }
}

/// Keadaan kosong yang ramah: ilustrasi ikon, judul, kalimat ajakan, aksi opsional.
class KosongRamah extends StatelessWidget {
  const KosongRamah({
    super.key,
    required this.ikon,
    required this.judul,
    required this.isi,
    this.aksi,
    this.ikonAksi = Icons.add_rounded,
    this.onAksi,
  });
  final IconData ikon;
  final String judul;
  final String isi;
  final String? aksi;
  final IconData ikonAksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jarak.s24, horizontal: Jarak.s16),
      child: Column(children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(color: Warna.primerMuda, shape: BoxShape.circle),
          child: Stack(alignment: Alignment.center, children: [
            Icon(ikon, size: 44, color: Warna.primer),
            const Positioned(
              right: 14,
              top: 14,
              child: CircleAvatar(radius: 6, backgroundColor: Warna.aksen),
            ),
          ]),
        ),
        const SizedBox(height: Jarak.s16),
        Text(judul, textAlign: TextAlign.center, style: t.titleMedium),
        const SizedBox(height: Jarak.s8),
        Text(isi, textAlign: TextAlign.center, style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        if (aksi != null) ...[
          const SizedBox(height: Jarak.s16),
          TombolKedua(label: aksi!, ikon: ikonAksi, lebarPenuh: false, onPressed: onAksi),
        ],
      ]),
    );
  }
}

/// Kotak bergradien merek, bersudut 16 dan berbayang biru (kartu utama UI lama).
class KotakMerek extends StatelessWidget {
  const KotakMerek({super.key, required this.child, this.padding = const EdgeInsets.all(Jarak.s16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradienMerek,
          borderRadius: BorderRadius.circular(Sudut.kartu),
          boxShadow: bayanganMerek,
        ),
        child: child,
      );
}

/// Header berwarna merek untuk layar utama tanpa app bar (Beranda): gradien
/// sampai ke balik status bar, sudut bawah membulat.
class HeaderMerek extends StatelessWidget {
  const HeaderMerek({super.key, required this.child, this.bawah = Jarak.s24});
  final Widget child;

  /// Ruang di bawah isi (untuk kartu yang menumpuk ke header).
  final double bawah;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Warna.primer, Warna.primerGelap],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Jarak.s16, Jarak.s16, Jarak.s16, bawah),
            child: child,
          ),
        ),
      );
}

/// Penanda bahwa kartu berada di kolom sempit [KisiKartu] (judul di bawah ikon).
class _DalamKisi extends InheritedWidget {
  const _DalamKisi({required super.child});
  static bool dari(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_DalamKisi>() != null;
  @override
  bool updateShouldNotify(_DalamKisi oldWidget) => false;
}

/// Kartu-kartu dalam kisi 2 kolom bila muat, 1 kolom bila huruf diperbesar.
/// Tinggi kartu sebaris disamakan; kartu ganjil terakhir selebar penuh.
class KisiKartu extends StatelessWidget {
  const KisiKartu({super.key, required this.children, this.lebarMin = 150});
  final List<Widget> children;

  /// Lebar minimum satu kolom pada huruf 1,0x (dikalikan skala huruf).
  final double lebarMin;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final skala = MediaQuery.textScalerOf(context).scale(100) / 100;
        final kolom = (c.maxWidth / (lebarMin * skala)).floor().clamp(1, 2);
        final baris = <Widget>[];
        for (var i = 0; i < children.length; i += kolom) {
          if (i > 0) baris.add(const SizedBox(height: Jarak.s12));
          if (kolom == 1 || i + 1 >= children.length) {
            baris.add(children[i]);
          } else {
            baris.add(IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _DalamKisi(child: children[i])),
                const SizedBox(width: Jarak.s12),
                Expanded(child: _DalamKisi(child: children[i + 1])),
              ]),
            ));
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: baris);
      });
}

/// Satu angka penting: judul, nilai besar, kalimat keterangan. Arti tidak hanya
/// lewat warna: [judul] dan [nilai] sudah memuat kata/tanda (+, −, Untung, Rugi).
/// [utama] = kartu bergradien merek (satu per layar, angka terpenting).
class KartuAngka extends StatelessWidget {
  const KartuAngka({
    super.key,
    required this.judul,
    required this.nilai,
    required this.ikon,
    this.keterangan,
    this.nada = Nada.netral,
    this.utama = false,
    this.lencana,
  });
  final String judul;
  final String nilai;
  final IconData ikon;
  final String? keterangan;
  final Nada nada;
  final bool utama;

  /// Pil kecil di samping judul (mis. "Untung"/"Rugi" pada kartu utama).
  final String? lencana;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = warnaNada(nada);
    final sempit = !utama && _DalamKisi.dari(context);
    final gayaJudul = t.titleSmall!.copyWith(color: utama ? Warna.putih : Warna.teks, fontWeight: FontWeight.w700);
    final isi = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sempit) ...[
          UbinIkon(ikon, nada: nada, ukuran: 40),
          const SizedBox(height: Jarak.s8),
          Text(judul, style: gayaJudul),
        ] else
          Row(children: [
            UbinIkon(ikon, nada: nada, diAtasMerek: utama, ukuran: utama ? 44 : 40),
            const SizedBox(width: Jarak.s12),
            Expanded(child: Text(judul, style: gayaJudul)),
          ]),
        if (lencana != null) ...[
          const SizedBox(height: Jarak.s8),
          ChipPil(lencana!, nada: nada, ikon: nada == Nada.error ? Icons.south_east_rounded : Icons.north_east_rounded),
        ],
        SizedBox(height: sempit ? Jarak.s4 : Jarak.s12),
        // Angka tidak boleh terbelah antarbaris; bila tidak muat (huruf sangat besar) mengecil.
        TeksUang(nilai,
            gaya: (utama ? t.headlineMedium! : (sempit ? t.titleLarge! : t.headlineSmall!))
                .copyWith(color: utama ? Warna.putih : (nada == Nada.netral ? Warna.teks : w.isi))),
        if (keterangan != null) ...[
          const SizedBox(height: Jarak.s8),
          Text(keterangan!,
              style: t.bodySmall!.copyWith(color: utama ? Warna.primerPudar : Warna.teksSekunder)),
        ],
      ],
    );
    if (utama) return KotakMerek(padding: const EdgeInsets.all(Jarak.s16), child: isi);
    return Card(child: Padding(padding: const EdgeInsets.all(Jarak.s16), child: isi));
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
    this.ikonAksi = Icons.arrow_forward_rounded,
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
      padding: const EdgeInsets.all(Jarak.s16),
      decoration: BoxDecoration(
        color: w.latar,
        borderRadius: BorderRadius.circular(Sudut.kartu),
        border: Border(left: BorderSide(color: w.isi, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(nada == Nada.error ? Icons.error_rounded : Icons.warning_rounded,
                color: w.isi, size: 28 * skalaIkon(context)),
            const SizedBox(width: Jarak.s12),
            Expanded(child: Text(judul, style: t.titleSmall!.copyWith(color: w.isi, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: Jarak.s8),
          Text(isi, style: t.bodyLarge),
          if (aksi != null) ...[
            const SizedBox(height: Jarak.s12),
            _TombolBanner(label: aksi!, ikon: ikonAksi, warna: w.isi, onPressed: onAksi),
          ],
        ],
      ),
    );
  }
}

/// Aksi banner: tombol putih bertulisan warna nada (kontras >= 6:1 di atas putih).
class _TombolBanner extends StatelessWidget {
  const _TombolBanner({required this.label, required this.ikon, required this.warna, this.onPressed});
  final String label;
  final IconData ikon;
  final Color warna;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(ikon, size: 24 * skalaIkon(context)),
        label: Text(label, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(tinggiSentuh),
          backgroundColor: Warna.permukaan,
          foregroundColor: warna,
        ),
      );
}

// --- Input Rupiah ---

final _ribuan = NumberFormat.decimalPattern('id_ID');

/// "12.500.000" (titik ribuan, tanpa Rp).
String ribuan(int v) => _ribuan.format(v);

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

/// Label isian di atas kotaknya: selalu utuh (turun baris), tidak dipotong
/// seperti label di dalam kotak saat huruf diperbesar.
class LabelIsian extends StatelessWidget {
  const LabelIsian({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          child,
        ],
      );
}

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
    final input = TextField(
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
        // Awalan "Rp" selalu terlihat (prefixText hanya muncul saat isian difokus).
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: Jarak.s16, end: Jarak.s8),
          child: Text('Rp', style: t.titleMedium!.copyWith(color: Warna.teksSekunder)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 10,
        errorMaxLines: 10,
      ),
      onChanged: onChanged == null ? null : (s) => onChanged!(bacaRupiah(s)),
    );
    return LabelIsian(label: label, child: input);
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
            label: batal, ikon: Icons.close_rounded, lebarPenuh: false, onPressed: () => Navigator.pop(ctx, false)),
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

/// Dialog pemberitahuan satu tombol (hasil simpan, alasan gagal).
Future<void> tampilkanPesan(
  BuildContext context, {
  required String judul,
  required String isi,
  String tombol = 'Mengerti',
  bool gagal = false,
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(gagal ? Icons.error_rounded : Icons.info_rounded,
            color: gagal ? Warna.error : Warna.peringatan, size: 36),
        title: Text(judul),
        content: SingleChildScrollView(child: Text(isi)),
        actions: [
          TombolUtama(label: tombol, ikon: Icons.check_rounded, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );

// --- Tanggal ---

const namaBulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

final _iso = DateFormat('yyyy-MM-dd');

/// yyyy-MM-dd (format tanggal di DB dan tx_form_spec).
String isoTanggal(DateTime t) => _iso.format(t);

/// "4 Oktober 2026"; teks asli bila bukan tanggal yyyy-MM-dd.
String tanggalPanjang(String iso) {
  final t = DateTime.tryParse(iso);
  return t == null ? iso : '${t.day} ${namaBulan[t.month - 1]} ${t.year}';
}

/// "4 Okt 2026".
String tanggalPendek(String iso) {
  final t = DateTime.tryParse(iso);
  return t == null ? iso : '${t.day} ${namaBulan[t.month - 1].substring(0, 3)} ${t.year}';
}

/// Pilih tanggal tanpa mengetik: tombol cepat "Hari ini" / "Kemarin" dan kalender.
/// Nilai = yyyy-MM-dd; null hanya untuk field opsional ([bolehKosong]).
class InputTanggal extends StatelessWidget {
  const InputTanggal({
    super.key,
    required this.label,
    required this.nilai,
    required this.onChanged,
    this.bolehKosong = false,
    this.teksKosong = '-',
    this.helperText,
    this.errorText,
    this.hariIni,
  });
  final String label;
  final String? nilai;
  final ValueChanged<String?> onChanged;
  final bool bolehKosong;
  final String teksKosong;
  final String? helperText;
  final String? errorText;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = hariIni ?? DateTime.now();
    final hari = DateTime(now.year, now.month, now.day);
    final kemarin = DateTime(hari.year, hari.month, hari.day - 1);
    final dipilih = nilai == null ? null : DateTime.tryParse(nilai!);
    String teks() {
      if (dipilih == null) return nilai ?? teksKosong;
      final keterangan = nilai == isoTanggal(hari)
          ? ' (hari ini)'
          : (nilai == isoTanggal(kemarin) ? ' (kemarin)' : '');
      return '${_namaHari[dipilih.weekday - 1]}, ${tanggalPanjang(nilai!)}$keterangan';
    }

    Future<void> kalender() async {
      final p = await showDatePicker(
        context: context,
        initialDate: dipilih ?? hari,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: label,
        cancelText: 'Batal',
        confirmText: 'Pilih',
      );
      if (p != null) onChanged(isoTanggal(p));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: t.titleSmall),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            helperText: helperText,
            helperMaxLines: 10,
            errorText: errorText,
            errorMaxLines: 10,
            prefixIcon: Icon(Icons.event_rounded, size: 24 * skalaIkon(context)),
          ),
          child: Text(teks(), style: t.titleSmall),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TombolKedua(
              label: 'Hari ini', ikon: Icons.today_rounded, lebarPenuh: false, onPressed: () => onChanged(isoTanggal(hari))),
          TombolKedua(
              label: 'Kemarin',
              ikon: Icons.history_rounded,
              lebarPenuh: false,
              onPressed: () => onChanged(isoTanggal(kemarin))),
          TombolKedua(label: 'Pilih tanggal', ikon: Icons.calendar_month_rounded, lebarPenuh: false, onPressed: kalender),
          if (bolehKosong && nilai != null)
            TombolKedua(label: 'Kosongkan', ikon: Icons.clear_rounded, lebarPenuh: false, onPressed: () => onChanged(null)),
        ]),
      ],
    );
  }
}

// --- Pilihan ---

class OpsiPilihan<T> {
  const OpsiPilihan(this.nilai, this.label, {this.keterangan});
  final T nilai;
  final String label;
  final String? keterangan;
}

/// Pilih satu dari beberapa: setiap pilihan baris besar (>= 56dp) dengan tanda
/// bulat dan tulisan, bukan dropdown kecil. [onChanged] null = terkunci.
class PilihanTunggal<T> extends StatelessWidget {
  const PilihanTunggal({
    super.key,
    required this.label,
    required this.opsi,
    required this.nilai,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.teksKosong = 'Belum ada yang bisa dipilih',
  });
  final String label;
  final List<OpsiPilihan<T>> opsi;
  final T? nilai;
  final ValueChanged<T>? onChanged;
  final String? errorText;
  final String? helperText;
  final String teksKosong;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: t.titleSmall),
        if (helperText != null) Text(helperText!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
        const SizedBox(height: 8),
        if (opsi.isEmpty) Text(teksKosong, style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        for (final o in opsi) ...[
          _BarisPilihan(
            label: o.label,
            keterangan: o.keterangan,
            terpilih: o.nilai == nilai,
            onTap: onChanged == null ? null : () => onChanged!(o.nilai),
          ),
          const SizedBox(height: 8),
        ],
        if (errorText != null) Text(errorText!, style: t.bodySmall!.copyWith(color: Warna.error)),
      ],
    );
  }
}

class _BarisPilihan extends StatelessWidget {
  const _BarisPilihan({required this.label, this.keterangan, required this.terpilih, this.onTap});
  final String label;
  final String? keterangan;
  final bool terpilih;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: terpilih,
      enabled: onTap != null,
      child: Material(
        color: terpilih ? Warna.primerMuda : Warna.permukaan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: terpilih ? Warna.primer : Warna.teksSekunder, width: terpilih ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tinggiTombolUtama),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(terpilih ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: terpilih ? Warna.primer : Warna.teksSekunder),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: t.bodyLarge!.copyWith(fontWeight: terpilih ? FontWeight.w700 : null)),
                    if (keterangan != null)
                      Text(keterangan!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu tombol pilihan (waktu laporan, jenis laporan, satuan, kondisi): terisi
/// dengan tanda centang bila terpilih, bergaris bila tidak. Arti tidak hanya lewat warna.
class TombolPilihan extends StatelessWidget {
  const TombolPilihan(
      {super.key, required this.label, required this.terpilih, this.onPressed, this.ikon = Icons.radio_button_unchecked_rounded});
  final String label;
  final bool terpilih;
  final VoidCallback? onPressed;

  /// Ikon saat tidak terpilih (terpilih selalu centang).
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    const ukuran = Size(tinggiSentuh, tinggiSentuh);
    final teks = Text(label, textAlign: TextAlign.center);
    final besar = 24 * skalaIkon(context);
    return Semantics(
      selected: terpilih,
      child: terpilih
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(Icons.check_rounded, size: besar),
              label: teks,
              style: FilledButton.styleFrom(minimumSize: ukuran),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(ikon, size: besar),
              label: teks,
              style: OutlinedButton.styleFrom(minimumSize: ukuran),
            ),
    );
  }
}

/// Pilihan pendek berupa deretan [TombolPilihan] yang turun baris bila tidak muat.
/// [banyak] = boleh memilih lebih dari satu.
class PilihanTombol<T> extends StatelessWidget {
  const PilihanTombol({
    super.key,
    required this.label,
    required this.opsi,
    required this.terpilih,
    required this.onPilih,
    this.errorText,
  });
  final String label;
  final List<OpsiPilihan<T>> opsi;
  final Set<T> terpilih;
  final ValueChanged<T> onPilih;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: t.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opsi)
          TombolPilihan(label: o.label, terpilih: terpilih.contains(o.nilai), onPressed: () => onPilih(o.nilai)),
      ]),
      if (errorText != null) ...[
        const SizedBox(height: 4),
        Text(errorText!, style: t.bodySmall!.copyWith(color: Warna.error)),
      ],
    ]);
  }
}

/// Kartu pilihan besar di layar "Apa yang terjadi?": label + penjelasan.
/// [alasanNonaktif] bukan null = tidak bisa dipilih; alasannya tetap ditampilkan.
class KartuPilihan extends StatelessWidget {
  const KartuPilihan(
      {super.key, required this.judul, this.penjelasan, this.alasanNonaktif, this.onTap, this.ikon, this.nada = Nada.netral});
  final String judul;
  final String? penjelasan;
  final String? alasanNonaktif;
  final VoidCallback? onTap;
  final IconData? ikon;
  final Nada nada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aktif = alasanNonaktif == null;
    return Semantics(
      button: true,
      enabled: aktif,
      child: Material(
        color: aktif ? Warna.permukaan : Warna.latar,
        elevation: aktif ? 3 : 0,
        shadowColor: Warna.bayangan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sudut.kartu),
          side: aktif ? BorderSide.none : const BorderSide(color: Warna.garis, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aktif ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(Jarak.s16),
              child: Row(children: [
                if (ikon != null) ...[
                  UbinIkon(ikon!, nada: aktif ? nada : Nada.netral),
                  const SizedBox(width: Jarak.s12),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(judul,
                        style: t.titleSmall!
                            .copyWith(color: aktif ? Warna.teks : Warna.teksSekunder, fontWeight: FontWeight.w700)),
                    if (penjelasan != null && penjelasan!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(penjelasan!, style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                    ],
                    if (!aktif) ...[
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lock_rounded, color: Warna.teksSekunder),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Belum bisa dipilih: $alasanNonaktif',
                              style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
                        ),
                      ]),
                    ],
                  ]),
                ),
                if (aktif) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Warna.primer, size: 32),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Laporan ---

/// Satu baris laporan: label kiri, angka rata kanan. Bila tidak muat dalam satu
/// baris (huruf besar), angka turun ke baris berikutnya, tetap rata kanan.
class BarisLaporan extends StatelessWidget {
  const BarisLaporan({
    super.key,
    required this.label,
    required this.nilai,
    this.tebal = false,
    this.warnaNilai,
    this.menjorok = 0,
  });
  final String label;
  final String nilai;
  final bool tebal;
  final Color? warnaNilai;

  /// Tingkat indentasi label (0 = tidak menjorok).
  final int menjorok;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gayaLabel = (tebal ? t.titleSmall : t.bodyLarge)!;
    final gayaNilai = gayaAngka(gayaLabel.copyWith(
        fontWeight: tebal ? FontWeight.w700 : FontWeight.w600, color: warnaNilai ?? Warna.teks));
    return Semantics(
      label: '$label: $nilai',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(left: 16.0 * menjorok, top: 6, bottom: 6),
        child: LayoutBuilder(builder: (context, c) {
          final ukur = TextPainter(
            text: TextSpan(text: nilai, style: gayaNilai),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final lebarNilai = ukur.width;
          ukur.dispose();
          final labelW = Text(label, style: gayaLabel);
          final nilaiW = Text(nilai, style: gayaNilai, textAlign: TextAlign.right);
          // Label butuh minimal 40% lebar agar tidak terpotong per huruf.
          if (lebarNilai + 12 <= c.maxWidth * 0.6) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: labelW),
              const SizedBox(width: 12),
              nilaiW,
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [labelW, nilaiW]);
        }),
      ),
    );
  }
}
