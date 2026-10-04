// Onboarding (UI-PLAN.md 3.7): langkah 1 nama usaha, langkah 2 ajakan membuat
// cadangan secara berkala. Nama disimpan sesudah langkah 2 agar ajakan cadangan
// selalu terbaca sekali.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'halaman_utama.dart';
import 'lainnya_page.dart' show batasHariCadangan;
import 'ui/komponen.dart';
import 'ui/tokens.dart';

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
  int _langkah = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _lanjut() {
    if (_formKey.currentState!.validate()) setState(() => _langkah = 1);
  }

  Future<void> _mulai() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', _nameController.text.trim());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: widget.sesudahnya ?? (_) => const HalamanUtama()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _langkah == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _langkah = 0);
      },
      child: Scaffold(
        body: SafeArea(child: _langkah == 0 ? _nama() : _cadangan()),
      ),
    );
  }

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
          Text('Sebelum mulai mencatat, boleh tahu nama peternakan Kakak?',
              style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
          const SizedBox(height: 24),
          LabelIsian(
            label: 'Nama peternakan / pemilik',
            child: TextFormField(
              controller: _nameController,
              style: t.bodyLarge,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Contoh: Ternak Cibeusi Makmur',
                prefixIcon: Icon(Icons.edit, color: Warna.aksenTeks),
                errorMaxLines: 10,
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Nama tidak boleh kosong ya' : null,
            ),
          ),
          const SizedBox(height: 32),
          TombolUtama(label: 'Lanjut', ikon: Icons.arrow_forward, onPressed: _lanjut),
        ],
      ),
    );
  }

  Widget _cadangan() {
    final t = Theme.of(context).textTheme;
    Widget langkah(String no, String isi) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Warna.primer,
              child: Text(no, style: t.titleSmall!.copyWith(color: Warna.putih)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(isi, style: t.bodyLarge)),
          ]),
        );
    return ListView(
      key: const ValueKey('cadangan'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Langkah 2 dari 2', style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        const SizedBox(height: 16),
        _gambar(Icons.cloud_upload_outlined),
        const SizedBox(height: 32),
        Text('Simpan cadangan secara berkala', style: t.headlineSmall!.copyWith(color: Warna.primer)),
        const SizedBox(height: 12),
        Text('Catatan hanya tersimpan di HP ini. Bila HP hilang, rusak, atau aplikasi terhapus, '
            'catatan ikut hilang.', style: t.bodyLarge),
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
        TombolUtama(label: 'Mengerti, mulai mencatat', ikon: Icons.check, onPressed: _mulai),
        const SizedBox(height: 12),
        TombolKedua(label: 'Kembali', ikon: Icons.arrow_back, onPressed: () => setState(() => _langkah = 0)),
      ],
    );
  }
}
