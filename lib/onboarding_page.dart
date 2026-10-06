// Onboarding (UI-PLAN.md 3.7): pengenalan 3 halaman yang bisa digeser (hanya
// sekali, bisa dilewati), lalu langkah 1 nama usaha dan langkah 2 ajakan membuat
// cadangan secara berkala. Nama disimpan sesudah langkah 2 agar ajakan cadangan
// selalu terbaca sekali.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'halaman_utama.dart';
import 'lainnya_page.dart' show batasHariCadangan;
import 'ui/ilustrasi.dart';
import 'ui/komponen.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

/// Kunci SharedPreferences: pengenalan 3 halaman sudah dilihat (dilewati atau "Mulai").
const kunciIntroDilihat = 'intro_dilihat';

class HalamanIntro {
  const HalamanIntro(this.judul, this.isi, this.ilustrasi);
  final String judul;
  final String isi;
  final JenisIlustrasi ilustrasi;
}

const halamanIntro = [
  HalamanIntro(
    'Catat usaha ternak dengan cara biasa',
    'Pilih apa yang terjadi: jual, beli pakan, bayar upah. SiKaya yang mengurus pembukuannya.',
    JenisIlustrasi.catat,
  ),
  HalamanIntro(
    'Lihat untung dan aset Anda',
    'Untung bulan ini, nilai kandang dan peralatan, serta stok pakan, semuanya terlihat dalam satu layar.',
    JenisIlustrasi.untungAset,
  ),
  HalamanIntro(
    'Data tersimpan di HP Anda',
    'Bisa dipakai tanpa internet. Cadangkan berkala supaya aman jika HP hilang atau rusak.',
    JenisIlustrasi.dataDiHp,
  ),
];

enum _Tahap { memuat, intro, nama, cadangan }

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.sesudahnya});

  /// Halaman sesudah onboarding (tes); null = HalamanUtama.
  final WidgetBuilder? sesudahnya;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _halaman = PageController();
  _Tahap _tahap = _Tahap.memuat;
  int _hal = 0;

  /// Pengenalan tampil di sesi ini: "kembali" dari langkah nama membukanya lagi.
  bool _introSesiIni = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    var dilihat = false;
    try {
      dilihat = (await SharedPreferences.getInstance()).getBool(kunciIntroDilihat) ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _introSesiIni = !dilihat;
      _tahap = dilihat ? _Tahap.nama : _Tahap.intro;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _halaman.dispose();
    super.dispose();
  }

  /// "Lewati" atau "Mulai": pengenalan tidak tampil lagi, lanjut ke langkah nama.
  Future<void> _selesaiIntro() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(kunciIntroDilihat, true);
    } catch (_) {}
    if (mounted) setState(() => _tahap = _Tahap.nama);
  }

  void _keHalaman(int i) =>
      _halaman.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  void _lanjut() {
    if (_formKey.currentState!.validate()) setState(() => _tahap = _Tahap.cadangan);
  }

  Future<void> _mulai() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', _nameController.text.trim());
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: widget.sesudahnya ?? (_) => const HalamanUtama()));
  }

  bool get _bolehKeluar => switch (_tahap) {
    _Tahap.memuat => true,
    _Tahap.intro => _hal == 0,
    _Tahap.nama => !_introSesiIni,
    _Tahap.cadangan => false,
  };

  /// Tombol kembali HP: halaman pengenalan sebelumnya, atau langkah sebelumnya.
  void _kembali() {
    switch (_tahap) {
      case _Tahap.intro:
        _keHalaman(_hal - 1);
      case _Tahap.nama:
        final terakhir = halamanIntro.length - 1;
        setState(() {
          _hal = terakhir;
          _tahap = _Tahap.intro;
        });
        // PageView dibuat ulang mulai halaman 1; pindahkan ke halaman terakhir yang tadi dilihat.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_halaman.hasClients) _halaman.jumpToPage(terakhir);
        });
      case _Tahap.cadangan:
        setState(() => _tahap = _Tahap.nama);
      case _Tahap.memuat:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _bolehKeluar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _kembali();
      },
      // Latar terang tanpa app bar biru: ikon status bar gelap agar terlihat.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: gayaSistem.copyWith(statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
        child: Scaffold(
          body: SafeArea(
            child: switch (_tahap) {
              _Tahap.memuat => const SizedBox.expand(),
              _Tahap.intro => _intro(),
              _Tahap.nama => _nama(),
              _Tahap.cadangan => _cadangan(),
            },
          ),
        ),
      ),
    );
  }

  // --- Pengenalan 3 halaman ---

  Widget _intro() {
    final t = Theme.of(context).textTheme;
    final terakhir = _hal == halamanIntro.length - 1;
    final logo = 32 * skalaIkon(context);
    return Column(
      key: const ValueKey('intro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kepala: logo merek (onboarding tetap memakai logo aplikasi) dan "Lewati".
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tinggiSentuh + Jarak.s8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s8, Jarak.s8, 0),
            child: Row(
              children: [
                Image.asset('assets/icon_ayam.png', width: logo, height: logo, semanticLabel: 'Logo SiKaya'),
                const SizedBox(width: Jarak.s8),
                Expanded(
                  child: Text('SiKaya', style: t.titleMedium!.copyWith(color: Warna.primer)),
                ),
                // Halaman terakhir: "Mulai" di bawah sudah sama dengan "Lewati".
                if (!terakhir) TextButton(onPressed: _selesaiIntro, child: const Text('Lewati')),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _halaman,
            itemCount: halamanIntro.length,
            onPageChanged: (i) => setState(() => _hal = i),
            itemBuilder: (context, i) => _isiIntro(halamanIntro[i]),
          ),
        ),
        _TitikHalaman(jumlah: halamanIntro.length, aktif: _hal),
        Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.s16, Jarak.s12, Jarak.s16, Jarak.s16),
          child: terakhir
              ? TombolUtama(label: 'Mulai', ikon: Icons.check_rounded, onPressed: _selesaiIntro)
              : TombolUtama(label: 'Lanjut', ikon: Icons.arrow_forward_rounded, onPressed: () => _keHalaman(_hal + 1)),
        ),
      ],
    );
  }

  /// Satu halaman pengenalan: isi di tengah tinggi halaman; ilustrasi mengecil bila
  /// huruf besar agar tulisan muat; bila tetap tidak muat, isi bisa digulir.
  Widget _isiIntro(HalamanIntro h) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final hurufBesar = MediaQuery.textScalerOf(context).scale(10) > 15;
        final ukuran = (c.maxHeight * (hurufBesar ? 0.22 : 0.42)).clamp(96.0, 240.0).toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Jarak.s24, Jarak.s16, Jarak.s24, Jarak.s16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: math.max(0, c.maxHeight - 2 * Jarak.s16)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ilustrasi(h.ilustrasi, ukuran: ukuran),
                const SizedBox(height: Jarak.s24),
                Semantics(
                  header: true,
                  child: Text(
                    h.judul,
                    textAlign: TextAlign.center,
                    style: t.headlineSmall!.copyWith(color: Warna.primer),
                  ),
                ),
                const SizedBox(height: Jarak.s12),
                Text(
                  h.isi,
                  textAlign: TextAlign.center,
                  style: t.bodyLarge!.copyWith(color: Warna.teksSekunder),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Langkah penyiapan ---

  Widget _gambar(IconData ikon) => Center(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Warna.primerMuda, shape: BoxShape.circle),
      child: Icon(ikon, size: 80, color: Warna.primer),
    ),
  );

  Widget _nama() {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('nama'),
        padding: const EdgeInsets.all(24),
        children: [
          Text('Langkah 1 dari 2', style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
          const SizedBox(height: 16),
          _gambar(Icons.store_mall_directory_rounded),
          const SizedBox(height: 32),
          Text('Halo, Juragan!', style: t.headlineMedium!.copyWith(color: Warna.primer)),
          const SizedBox(height: 8),
          Text(
            'Sebelum mulai mencatat, boleh tahu nama peternakan Kakak?',
            style: t.bodyLarge!.copyWith(color: Warna.teksSekunder),
          ),
          const SizedBox(height: 24),
          LabelIsian(
            label: 'Nama peternakan / pemilik',
            child: TextFormField(
              controller: _nameController,
              style: t.bodyLarge,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Contoh: Ternak Cibeusi Makmur',
                prefixIcon: Icon(Icons.edit_rounded, color: Warna.aksenTeks),
                errorMaxLines: 10,
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Nama tidak boleh kosong ya' : null,
            ),
          ),
          const SizedBox(height: 32),
          TombolUtama(label: 'Lanjut', ikon: Icons.arrow_forward_rounded, onPressed: _lanjut),
        ],
      ),
    );
  }

  Widget _cadangan() {
    final t = Theme.of(context).textTheme;
    Widget langkah(String no, String isi) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Warna.primer,
            child: Text(no, style: t.titleSmall!.copyWith(color: Warna.putih)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(isi, style: t.bodyLarge)),
        ],
      ),
    );
    return ListView(
      key: const ValueKey('cadangan'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Langkah 2 dari 2', style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        const SizedBox(height: 16),
        _gambar(Icons.cloud_upload_rounded),
        const SizedBox(height: 32),
        Text('Simpan cadangan secara berkala', style: t.headlineSmall!.copyWith(color: Warna.primer)),
        const SizedBox(height: 12),
        Text(
          'Catatan hanya tersimpan di HP ini. Bila HP hilang, rusak, atau aplikasi terhapus, '
          'catatan ikut hilang.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 20),
        Text('Seminggu sekali:', style: t.titleSmall),
        const SizedBox(height: 12),
        langkah('1', 'Buka menu Lainnya (pojok kanan bawah).'),
        langkah('2', 'Tekan tombol "Ekspor cadangan".'),
        langkah('3', 'Simpan filenya di Google Drive, atau kirim ke WhatsApp Anda sendiri.'),
        const SizedBox(height: 8),
        BannerPeringatan(
          judul: 'Pengingat',
          isi: 'Menu Lainnya akan mengingatkan bila sudah $batasHariCadangan hari belum membuat cadangan.',
          nada: Nada.netral,
        ),
        const SizedBox(height: 32),
        TombolUtama(label: 'Mengerti, mulai mencatat', ikon: Icons.check_rounded, onPressed: _mulai),
        const SizedBox(height: 12),
        TombolKedua(
          label: 'Kembali',
          ikon: Icons.arrow_back_rounded,
          onPressed: () => setState(() => _tahap = _Tahap.nama),
        ),
      ],
    );
  }
}

/// Titik penanda halaman: titik aktif memanjang dan berwarna primer. Pembaca layar
/// membaca "Halaman 2 dari 3".
class _TitikHalaman extends StatelessWidget {
  const _TitikHalaman({required this.jumlah, required this.aktif});
  final int jumlah;
  final int aktif;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Halaman ${aktif + 1} dari $jumlah',
    excludeSemantics: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < jumlah; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: Jarak.s4),
            width: i == aktif ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              // Titik tidak aktif: tepiIsian (>= 3:1 di atas latar, WCAG 1.4.11).
              color: i == aktif ? Warna.primer : Warna.tepiIsian,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
      ],
    ),
  );
}
