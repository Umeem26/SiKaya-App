import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'halaman_utama.dart';
import 'onboarding_page.dart';
import 'ui/tokens.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() async {
    // Tunggu 2 detik biar logonya tampil (Estetika)
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final String? ownerName = prefs.getString('owner_name');

    if (!mounted) return;

    // Nama sudah ada -> Beranda; belum -> isi nama dulu (onboarding).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ownerName != null && ownerName.isNotEmpty
            ? const HalamanUtama()
            : const OnboardingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.primer,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Warna.putih, shape: BoxShape.circle),
              child: Image.asset('assets/icon_ayam.png', width: 100),
            ),
            const SizedBox(height: 20),
            Text(
              "SiKaya",
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Warna.putih),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Warna.putih),
          ],
        ),
      ),
    );
  }
}
