import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database/database_helper.dart';
import 'asset_model.dart';
import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

enum _Periode { bulanIni, bulanLalu, tahunIni, rentang }

const _labelPeriode = {
  _Periode.bulanIni: 'Bulan ini',
  _Periode.bulanLalu: 'Bulan lalu',
  _Periode.tahunIni: 'Tahun ini',
  _Periode.rentang: 'Rentang bebas',
};

class _ReportPageState extends State<ReportPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Color polbanBlue = const Color(0xFF1E549F);
  final Color polbanOrange = const Color(0xFFFA9C1B);

  bool _showFinance = true;
  bool _isLoading = true;
  String _ownerName = "Nama Peternak";

  late Report _r;

  /// Posisi Keuangan sehari sebelum _from (saldo awal ekuitas).
  Report? _awal;
  _Periode _periode = _Periode.bulanIni;
  late DateTime _from;
  late DateTime _asOf;
  List<AssetModel> _operationalAssets = [];

  @override
  void initState() {
    super.initState();
    _setPeriode(_Periode.bulanIni);
    _loadData();
  }

  /// Laba Rugi [_from, _asOf]; Posisi Keuangan per _asOf. Periode berjalan s.d. hari ini.
  void _setPeriode(_Periode p, [DateTimeRange? rentang]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _periode = p;
    switch (p) {
      case _Periode.bulanIni:
        _from = DateTime(now.year, now.month, 1);
        _asOf = today;
      case _Periode.bulanLalu:
        _from = DateTime(now.year, now.month - 1, 1);
        _asOf = DateTime(now.year, now.month, 0);
      case _Periode.tahunIni:
        _from = DateTime(now.year, 1, 1);
        _asOf = today;
      case _Periode.rentang:
        _from = rentang!.start;
        _asOf = rentang.end;
    }
  }

  Future<void> _gantiPeriode(_Periode? p) async {
    if (p == null) return;
    DateTimeRange? rentang;
    if (p == _Periode.rentang) {
      rentang = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: _from, end: _asOf),
      );
      if (rentang == null) return;
    }
    _setPeriode(p, rentang);
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('owner_name') ?? "Nama Peternak";

    final laporan = await AccountingRepository.instance.loadReport(asOf: _asOf, from: _from);
    final assets = await _dbHelper.readAllAssets();

    if (mounted) {
      setState(() {
        _ownerName = name;
        _r = laporan.report;
        _awal = laporan.opening;
        _operationalAssets = assets.where((a) => a.kategori == 'Operasional Habis Pakai').toList();
        _isLoading = false;
      });
    }
  }

  String _tgl(DateTime t) => DateFormat('dd MMMM yyyy').format(t);
  String get _teksPeriode => "Untuk Periode ${_tgl(_from)} s.d. ${_tgl(_asOf)}";
  String get _teksPer => "Per ${_tgl(_asOf)}";

  // Saldo awal + perubahan periode (invarian D2: akhir = awal + laba - prive periode).
  int get _modalAwal => _awal?.modalDisetor ?? 0;
  int get _saldoLabaAwal => _awal?.saldoLaba ?? 0;
  int get _privePeriode => _r.prive - (_awal?.prive ?? 0);

  String _fmt(int? val) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(val ?? 0);

  static const _labelBeban = {
    ExpenseKind.bpp: 'Beban Pokok Penjualan (Ternak)',
    ExpenseKind.pakan: 'Beban Pakan',
    ExpenseKind.obat: 'Beban Obat & Vitamin',
    ExpenseKind.listrikAir: 'Beban Listrik dan Air',
    ExpenseKind.tenagaKerja: 'Beban Tenaga Kerja',
    ExpenseKind.perawatan: 'Beban Perawatan Kandang',
    ExpenseKind.penyusutan: 'Beban Penyusutan',
    ExpenseKind.bunga: 'Beban Bunga',
    ExpenseKind.kerugianTernak: 'Beban Kerugian Ternak',
    ExpenseKind.lain: 'Beban Lain-lain',
  };

  List<MapEntry<String, int>> get _barisBeban => [
        for (final k in ExpenseKind.values)
          if (_r.beban[k] != null) MapEntry(_labelBeban[k]!, _r.beban[k]!),
      ];

  List<(String, String, int)> get _barisAset => [
        ('1-1001', 'Kas', _r.kas),
        ('1-1003', 'Piutang Usaha', _r.piutang),
        ('1-1004', 'Persediaan Pakan', _r.persediaan[StockItem.pakan] ?? 0),
        ('1-1007', 'Persediaan Obat & Vitamin', _r.persediaan[StockItem.obat] ?? 0),
        ('1-1008', 'Persediaan Ternak', _r.persediaan[StockItem.ternak] ?? 0),
        ('1-2001', 'Aset Tetap (Harga Perolehan)', _r.asetTetapBruto),
        ('1-2002', 'Akumulasi Penyusutan', -_r.akumulasiPenyusutan),
      ];

  int get _ekuitas => _r.modalDisetor + _r.saldoLaba;

  /// Peringatan: transaksi perlu_ditinjau (tidak dihitung) dan laporan tidak seimbang.
  Widget _peringatan() {
    final w = _r.peringatanTinjau;
    if (w == null && _r.balanced) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange[50], border: Border.all(color: Colors.orange)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_r.balanced)
          Text("Laporan TIDAK seimbang: aset ${_fmt(_r.totalAset)} vs liabilitas + ekuitas ${_fmt(_r.totalLiabilitasEkuitas)}.",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        if (w != null) ...[
          Text(w.pesan, style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final f in _r.perluDitinjau)
            Text("- Transaksi #${f.txId}: ${f.detail} (${_fmt(f.nilai)})", style: const TextStyle(fontSize: 12)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Pusat Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: polbanBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: polbanBlue))
        : Column(
            children: [
              Container(
                color: polbanBlue,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(50)),
                  child: Row(children: [_buildToggle("Laporan Keuangan", true), _buildToggle("Laporan Asset Tetap", false)]),
                ),
              ),
              if (_showFinance)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    const Text("Periode: "),
                    DropdownButton<_Periode>(
                      value: _periode,
                      items: [for (final p in _Periode.values) DropdownMenuItem(value: p, child: Text(_labelPeriode[p]!))],
                      onChanged: _gantiPeriode,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text("${DateFormat('dd/MM/yyyy').format(_from)} - ${DateFormat('dd/MM/yyyy').format(_asOf)}", style: const TextStyle(fontSize: 12))),
                  ]),
                ),
              Expanded(child: _showFinance ? _buildFinanceSection() : _buildAssetSection()),
            ],
          ),
    );
  }

  Widget _buildToggle(String text, bool isFinance) {
    bool active = _showFinance == isFinance;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showFinance = isFinance),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(50)),
          child: Center(child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: active ? polbanBlue : Colors.white70))),
        ),
      ),
    );
  }

  Widget _buildFinanceSection() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: polbanBlue, unselectedLabelColor: Colors.grey, indicatorColor: polbanOrange, labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [Tab(text: "LABA RUGI"), Tab(text: "MODAL"), Tab(text: "NERACA")],
            ),
          ),
          _peringatan(),
          Expanded(
            child: TabBarView(children: [_tabLabaRugi(), _tabModal(), _tabNeraca()]),
          )
        ],
      ),
    );
  }

  // --- TAB LABA RUGI ---
  Widget _tabLabaRugi() {
    return _excelScaffold(
      onPrint: _printLabaRugiPDF,
      title: "Laporan Laba Rugi",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _excelHeader(_ownerName, "Laporan Laba Rugi", _teksPeriode),
          const SizedBox(height: 20),
          _boldText("A. Pendapatan"),
          _excelRow("Pendapatan Penjualan", _r.pendapatan, showUnderline: true),
          _excelTotalRow("Total Pendapatan", _r.pendapatan),
          const SizedBox(height: 20),
          _boldText("B. Beban"),
          for (final b in _barisBeban) _excelRow(b.key, b.value),
          _excelTotalRow("Total Beban", _r.bebanTotal),
          const SizedBox(height: 30),
          _excelGrandTotal("LABA (RUGI) BERSIH", _r.labaBersih),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- TAB MODAL (ekuitas: modal disetor + saldo laba) ---
  Widget _tabModal() {
    return _excelScaffold(
      onPrint: _printModalPDF,
      title: "Laporan Perubahan Ekuitas",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _excelHeader(_ownerName, "Laporan Perubahan Ekuitas", _teksPeriode),
          const SizedBox(height: 20),
          _boldText("A. Modal Disetor"),
          _excelRow("Modal Disetor Awal", _modalAwal),
          _excelRow("Setoran Modal Periode Ini", _r.modalDisetor - _modalAwal, showUnderline: true),
          _excelTotalRow("Modal Disetor Akhir", _r.modalDisetor),
          const SizedBox(height: 20),
          _boldText("B. Saldo Laba"),
          _excelRow("Saldo Laba Awal", _saldoLabaAwal),
          _excelRow("Laba (Rugi) Bersih Periode Ini", _r.labaBersih),
          _excelRow("Prive (Penarikan Pemilik)", -_privePeriode, showUnderline: true),
          _excelTotalRow("Saldo Laba Akhir", _r.saldoLaba),
          const SizedBox(height: 30),
          _excelGrandTotal("TOTAL EKUITAS", _ekuitas),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- TAB NERACA (Laporan Posisi Keuangan) ---
  Widget _tabNeraca() {
    return _excelScaffold(
      onPrint: _printNeracaPDF,
      title: "Laporan Posisi Keuangan",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _excelHeader(_ownerName, "Laporan Posisi Keuangan", _teksPer),
          const SizedBox(height: 20),
          _boldText("ASET"),
          for (final a in _barisAset) _neracaRow(a.$1, a.$2, a.$3),
          const Divider(thickness: 2),
          _excelGrandTotal("TOTAL ASET", _r.totalAset),
          const SizedBox(height: 30),
          _boldText("LIABILITAS & EKUITAS"),
          const Text("Liabilitas", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          _neracaRow("2-1001", "Utang", _r.utang),
          const SizedBox(height: 10),
          const Text("Ekuitas", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          _neracaRow("3-1001", "Modal Disetor", _r.modalDisetor),
          _neracaRow("3-2001", "Saldo Laba", _r.saldoLaba),
          const Divider(thickness: 2),
          _excelGrandTotal("TOTAL LIABILITAS & EKUITAS", _r.totalLiabilitasEkuitas),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _excelScaffold({required String title, required Widget content, required VoidCallback onPrint}) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: onPrint, label: const Text("Export PDF"), icon: const Icon(Icons.picture_as_pdf), backgroundColor: Colors.redAccent),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: content)),
    );
  }
  Widget _excelHeader(String t1, String t2, String t3) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Column(children: [Text(t1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(t2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(t3, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
    );
  }
  Widget _boldText(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
  Widget _excelRow(String label, int? val, {bool showUnderline = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Container(decoration: showUnderline ? const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))) : null, child: Text(_fmt(val)))]));
  Widget _neracaRow(String code, String label, int? val) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 60, child: Text(code, style: const TextStyle(fontSize: 12, color: Colors.grey))), Expanded(child: Text(label)), Text(_fmt(val))]));
  Widget _excelTotalRow(String label, int? val) => Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Text(_fmt(val), style: const TextStyle(fontWeight: FontWeight.bold))]));
  Widget _excelGrandTotal(String label, int? val) => Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 2), bottom: BorderSide(color: Colors.black, width: 2))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(_fmt(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]));
  Widget _buildAssetSection() {return Scaffold(body: _operationalAssets.isEmpty ? const Center(child: Text("Belum ada data", style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(20), itemCount: _operationalAssets.length, itemBuilder: (context, index) { final item = _operationalAssets[index]; return Card(child: ListTile(leading: const Icon(Icons.inventory, color: Colors.orange), title: Text(item.nama, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${item.jumlah} ${item.satuan}"))); },));}

  // --- PDF GENERATOR (Update Format PDF) ---
  pw.Widget _pdfHeaderBox(String title, String periode) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(children: [
        pw.Text(_ownerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text(periode, style: pw.TextStyle(fontSize: 12)),
      ]),
    );
  }

  Future<void> _printLabaRugiPDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _pdfHeaderBox("Laporan Laba Rugi", _teksPeriode),
      pw.SizedBox(height: 20),
      _pdfBold("A. Pendapatan"),
      _pdfRow("Pendapatan Penjualan", _r.pendapatan, underline: true),
      _pdfTotalRow("Total Pendapatan", _r.pendapatan),
      pw.SizedBox(height: 15),
      _pdfBold("B. Beban"),
      for (final b in _barisBeban) _pdfRow(b.key, b.value),
      _pdfTotalRow("Total Beban", _r.bebanTotal),
      pw.SizedBox(height: 20),
      _pdfGrandTotal("LABA (RUGI) BERSIH", _r.labaBersih),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printModalPDF() async { final pdf = pw.Document(); pdf.addPage(pw.Page(build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfHeaderBox("Laporan Perubahan Ekuitas", _teksPeriode), pw.SizedBox(height: 20), _pdfBold("A. Modal Disetor"), _pdfRow("Modal Disetor Awal", _modalAwal), _pdfRow("Setoran Modal Periode Ini", _r.modalDisetor - _modalAwal, underline: true), _pdfTotalRow("Modal Disetor Akhir", _r.modalDisetor), pw.SizedBox(height: 15), _pdfBold("B. Saldo Laba"), _pdfRow("Saldo Laba Awal", _saldoLabaAwal), _pdfRow("Laba (Rugi) Bersih Periode Ini", _r.labaBersih), _pdfRow("Prive (Penarikan Pemilik)", -_privePeriode, underline: true), _pdfTotalRow("Saldo Laba Akhir", _r.saldoLaba), pw.SizedBox(height: 20), _pdfGrandTotal("TOTAL EKUITAS", _ekuitas)]))); await Printing.layoutPdf(onLayout: (format) async => pdf.save()); }
  Future<void> _printNeracaPDF() async { final pdf = pw.Document(); pdf.addPage(pw.Page(build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfHeaderBox("Laporan Posisi Keuangan", _teksPer), pw.SizedBox(height: 20), _pdfBold("ASET"), for (final a in _barisAset) _pdfRowCode(a.$1, a.$2, a.$3), pw.Divider(), _pdfGrandTotal("TOTAL ASET", _r.totalAset), pw.SizedBox(height: 20), _pdfBold("LIABILITAS & EKUITAS"), _pdfBold("Liabilitas"), _pdfRowCode("2-1001", "Utang", _r.utang), pw.SizedBox(height: 5), _pdfBold("Ekuitas"), _pdfRowCode("3-1001", "Modal Disetor", _r.modalDisetor), _pdfRowCode("3-2001", "Saldo Laba", _r.saldoLaba), pw.Divider(), _pdfGrandTotal("TOTAL LIABILITAS & EKUITAS", _r.totalLiabilitasEkuitas)]))); await Printing.layoutPdf(onLayout: (format) async => pdf.save()); }

  // Helper Widgets PDF (Sama seperti sebelumnya)
  pw.Widget _pdfBold(String t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
  pw.Widget _pdfRow(String l, int? v, {bool underline = false}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 20), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l), pw.Container(decoration: underline ? const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())) : null, child: pw.Text(_fmt(v)))]));
  pw.Widget _pdfRowCode(String c, String l, int? v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(children: [pw.SizedBox(width: 50, child: pw.Text(c, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))), pw.Expanded(child: pw.Text(l)), pw.Text(_fmt(v))]));
  pw.Widget _pdfTotalRow(String l, int? v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 20), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(_fmt(v), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]));
  pw.Widget _pdfGrandTotal(String l, int? v) => pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 5), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)), pw.Text(_fmt(v), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))]));
}