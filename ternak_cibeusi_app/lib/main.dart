import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'splash_page.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  SystemChrome.setSystemUIOverlayStyle(gayaSistem);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home = const SplashPage()});

  /// Halaman awal; integration test memulai dari onboarding dengan layanan pengganti.
  final Widget home;

  // Ukuran huruf mengikuti pengaturan HP: tidak ada builder yang mengubah textScaler.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiKaya',
      theme: temaSikaya(),
      themeMode: ThemeMode.light,
      // Bawaan semua halaman; splash menimpanya dengan bilah navigasi biru.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: gayaSistem, child: child!),
      home: home,
    );
  }
}
