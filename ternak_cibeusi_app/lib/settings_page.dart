import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database/database_helper.dart';
import 'accounting/repository.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'splash_page.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color polbanBlue = const Color(0xFF1E549F);
  final Color polbanOrange = const Color(0xFFFA9C1B);
  String _ownerName = "Administrator";

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  void _loadOwnerName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _ownerName = prefs.getString('owner_name') ?? "Administrator");
  }

  Future<void> _backupData() async {
     try {
      final trans = await AccountingRepository.instance.transactions();
      if (trans.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data kosong."))); return; }
      List<List<dynamic>> rows = [];
      rows.add(["Tanggal", "Tipe", "Kategori", "Nominal", "Deskripsi"]);
      for (var t in trans) { rows.add([t.date, t.txType.code, t.category, t.amount, t.description]); }
      String csvData = const ListToCsvConverter().convert(rows);
      String? filePath;
      String fileName = "Backup_Ternak_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
      if (Platform.isWindows) { final dir = await getDownloadsDirectory(); if (dir != null) filePath = "${dir.path}\\$fileName"; } 
      else { final dir = await getExternalStorageDirectory(); if (dir != null) filePath = "${dir.path}/$fileName"; }
      if (filePath != null) { final file = File(filePath); await file.writeAsString(csvData); _showDialog("Backup Berhasil", "File di:\n$filePath"); }
    } catch (e) { _showDialog("Gagal", e.toString()); }
  }
  void _showDialog(String t, String c) => showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Text(t), content: Text(c), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))]));

  void _showCloseBookDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: const Text("Tutup Buku?"), content: const Text("Data reset & saldo jadi modal awal."), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")), ElevatedButton(onPressed: () async { Navigator.pop(ctx); await DatabaseHelper.instance.closeBookAndReset(); }, child: const Text("Ya"))]));
  }

  void _showResetDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: const Text("Hapus Semua Data?"), content: const Text("PERINGATAN: Semua data & Nama Peternakan akan dihapus."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await DatabaseHelper.instance.nukeDatabase(); final prefs = await SharedPreferences.getInstance(); await prefs.clear(); if (!mounted) return; Navigator.pop(ctx); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SplashPage()), (route) => false); }, child: const Text("Hapus Semuanya", style: TextStyle(color: Colors.white)))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: polbanBlue, foregroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFILE CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Row(
                children: [
                  CircleAvatar(radius: 35, backgroundColor: polbanBlue.withOpacity(0.1), child: Icon(Icons.person, size: 40, color: polbanBlue)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_ownerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 5),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: polbanOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("Pemilik Peternakan", style: TextStyle(color: polbanOrange, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 35),

            // MENU ITEMS
            _header("Manajemen Data"),
            _menuCard([
              _tile(Icons.download_rounded, "Backup Data", "Simpan ke CSV", Colors.green, _backupData),
              const Divider(height: 1),
              _tile(Icons.history_edu_rounded, "Tutup Buku", "Reset periode akuntansi", polbanBlue, _showCloseBookDialog),
            ]),
            
            const SizedBox(height: 25),
            _header("Zona Bahaya"),
            _menuCard([
              _tile(Icons.delete_forever_rounded, "Reset Aplikasi", "Hapus data permanen", Colors.redAccent, _showResetDialog),
            ]),
            
            const SizedBox(height: 50),
            Center(
              child: Column(
                children: [
                  Icon(Icons.code, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("Versi 1.1.0 (Polban Edition)", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 5), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey[800])));
  
  Widget _menuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(children: children),
    );
  }

  Widget _tile(IconData i, String t, String s, Color c, VoidCallback tap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: c, size: 22)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: tap,
    );
  }
}