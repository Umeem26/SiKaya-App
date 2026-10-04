import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import 'list_asset_page.dart';
import 'list_finance_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'database/database_helper.dart';
import 'accounting/repository.dart';
import 'splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiKaya App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), 
        fontFamily: 'Roboto',
      ),
      home: const SplashPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // PALET WARNA BIRU KONSISTEN
  final Color bluePrimary = const Color(0xFF1E549F);
  final Color blueDark = const Color(0xFF153E75);
  final Color blueAccent = const Color(0xFF4FA3D1); // Pengganti Oranye
  
  int _totalTernak = 0;
  double _saldoKas = 0;
  double _totalMasuk = 0;
  double _totalKeluar = 0;
  String _lastUpdate = "-";
  String _ownerName = "Juragan Ternak"; 

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() async {
    final db = DatabaseHelper.instance;
    final prefs = await SharedPreferences.getInstance();

    String? savedName = prefs.getString('owner_name');
    final assets = await db.readAllAssets();
    int countTernak = 0;
    for (var a in assets) {
      if (a.kategori.contains('Ternak')) countTernak += a.jumlah;
    }
    final kas = (await AccountingRepository.instance.loadReport(asOf: DateTime.now())).kas;

    if (mounted) {
      setState(() {
        _ownerName = savedName ?? "Juragan Ternak"; 
        _totalTernak = countTernak;
        _totalMasuk = kas.masuk.toDouble();
        _totalKeluar = kas.keluar.toDouble();
        _saldoKas = kas.saldo.toDouble();
        _lastUpdate = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  String _fmtUang(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _fmtKecil(double amount) {
    if (amount >= 1000000) {
      return "${(amount / 1000000).toStringAsFixed(1)} Jt";
    }
    return NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Header Biru Melengkung
          Container(
            height: 280, 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bluePrimary, blueDark],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // 1. HEADER (Nama & Profil)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Halo, Juragan", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(_ownerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF1E549F))),
                      )
                    ],
                  ),
                ),

                // 2. KARTU SALDO UTAMA (Model Credit Card)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [blueAccent, bluePrimary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: bluePrimary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Saldo Kas", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withOpacity(0.5)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(_fmtUang(_saldoKas), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.update, color: Colors.white70, size: 14),
                            const SizedBox(width: 5),
                            Text("Update: $_lastUpdate", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // 3. RINGKASAN STATISTIK (3 Kotak Kecil)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _miniStatCard(Icons.pets, "Populasi", "$_totalTernak Ekor", Colors.blueAccent),
                      const SizedBox(width: 12),
                      _miniStatCard(Icons.arrow_downward_rounded, "Masuk", _fmtKecil(_totalMasuk), Colors.green),
                      const SizedBox(width: 12),
                      _miniStatCard(Icons.arrow_upward_rounded, "Keluar", _fmtKecil(_totalKeluar), Colors.redAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. GRID MENU UTAMA
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Menu Utama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: blueDark)),
                        const SizedBox(height: 20),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 1.3,
                            children: [
                              _menuBtn("Aset Ternak", Icons.inventory_2_rounded, bluePrimary, () => _navTo(const ListAssetPage())),
                              _menuBtn("Keuangan", Icons.monetization_on_rounded, blueDark, () => _navTo(const ListFinancePage())),
                              _menuBtn("Laporan", Icons.analytics_rounded, Colors.teal, () => _navTo(const ReportPage())),
                              _menuBtn("Pengaturan", Icons.settings_rounded, Colors.blueGrey, () => _navTo(const SettingsPage())),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    _loadSummary();
  }

  Widget _miniStatCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _menuBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF), // Biru sangat muda
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}