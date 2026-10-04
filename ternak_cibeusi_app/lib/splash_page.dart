// Splash Flutter sesudah splash native (flutter_native_splash, latar biru logo).
// Bingkai pertama identik dengan splash native: latar Warna.primer, lingkaran
// putih 160dp berisi logo tepat di tengah layar, sehingga tidak ada kedip putih
// atau loncatan. Lalu logo naik halus dan nama + tagline muncul; total maks 1,2 detik.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'halaman_utama.dart';
import 'onboarding_page.dart';
import 'ui/tokens.dart';

/// Lama splash Flutter (animasi + jeda baca); batas brief: 1,2 detik.
const lamaSplash = Duration(milliseconds: 1200);
const _lamaAnimasi = Duration(milliseconds: 600);

/// Bingkai pertama ditahan dulu: di Android 11 ke bawah sistem masih memudarkan
/// jendela splash ke jendela aplikasi (~250-400 ms); bila logo sudah bergerak, tampak logo ganda.
const _tahanAwal = Duration(milliseconds: 400);

/// Diameter lingkaran logo = lingkaran ikon splash Android 12 (160dp).
const diameterLogoSplash = 160.0;

const taglineSplash = 'Catatan keuangan & aset peternakan';

const _logo = AssetImage('assets/splash/splash_logo.png');

/// Decode logo splash sebelum runApp (splash native masih tampil), sehingga bingkai
/// Flutter pertama sudah berisi logo: tidak ada bingkai biru kosong di antaranya.
Future<void> siapkanLogoSplash() {
  final selesai = Completer<void>();
  final aliran = _logo.resolve(ImageConfiguration.empty);
  late final ImageStreamListener pendengar;
  pendengar = ImageStreamListener((_, _) {
    if (!selesai.isCompleted) selesai.complete();
    aliran.removeListener(pendengar);
  }, onError: (_, _) {
    if (!selesai.isCompleted) selesai.complete(); // tanpa logo pun aplikasi tetap jalan
    aliran.removeListener(pendengar);
  });
  aliran.addListener(pendengar);
  return selesai.future.timeout(const Duration(seconds: 2), onTimeout: () {});
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.tujuan});

  /// Pengganti pemilih halaman berikutnya (tes); null = Beranda/onboarding menurut nama usaha.
  final Future<Widget> Function()? tujuan;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: _lamaAnimasi);
  late final Animation<double> _naik = CurvedAnimation(parent: _a, curve: Curves.easeOutCubic);
  late final Animation<double> _teks = CurvedAnimation(parent: _a, curve: const Interval(0.35, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    // Mulai sesudah bingkai pertama tergambar (bingkai itu = splash native), sehingga
    // animasi tidak "habis" selama mesin grafis masih memanaskan diri di HP lambat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lanjut(); // lamaSplash dihitung dari bingkai pertama (termasuk masa tahan)
      Future<void>.delayed(_tahanAwal, () {
        if (mounted) _a.forward();
      });
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Future<Widget> _pilihTujuan() async {
    final prefs = await SharedPreferences.getInstance();
    final nama = prefs.getString('owner_name');
    // Nama sudah ada -> Beranda; belum -> isi nama dulu (onboarding).
    return nama != null && nama.isNotEmpty ? const HalamanUtama() : const OnboardingPage();
  }

  Future<void> _lanjut() async {
    // Memuat pengaturan berjalan bersamaan dengan animasi; splash tidak pernah lebih dari lamaSplash
    // kecuali penyimpanan HP sangat lambat.
    final hasil = await Future.wait([
      (widget.tujuan ?? _pilihTujuan)(),
      Future<void>.delayed(lamaSplash),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => hasil.first as Widget,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Warna.primer,
      ),
      child: Scaffold(
        backgroundColor: Warna.primer,
        body: AnimatedBuilder(
          animation: _a,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // Logo: mulai tepat di tengah (sama dengan splash native), naik 56dp.
              Center(
                child: Transform.translate(
                  offset: Offset(0, -56 * _naik.value),
                  child: const Image(
                    image: _logo,
                    width: diameterLogoSplash,
                    height: diameterLogoSplash,
                    semanticLabel: 'Logo SiKaya',
                  ),
                ),
              ),
              // Nama + tagline menempel di bawah logo yang sudah naik (tidak menumpuk walau huruf besar).
              LayoutBuilder(
                builder: (context, c) => Stack(children: [
                  Positioned(
                    left: Jarak.s24,
                    right: Jarak.s24,
                    top: c.maxHeight / 2 - 56 * _naik.value + diameterLogoSplash / 2 + Jarak.s24 + 16 * (1 - _teks.value),
                    child: Opacity(
                      opacity: _teks.value,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('SiKaya', style: t.headlineMedium!.copyWith(color: Warna.putih)),
                        const SizedBox(height: Jarak.s4),
                        Text(taglineSplash,
                            textAlign: TextAlign.center, style: t.bodyLarge!.copyWith(color: Warna.primerPudar)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
