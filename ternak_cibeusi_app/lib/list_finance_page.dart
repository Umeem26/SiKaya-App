import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'accounting/engine.dart' show roundHalfAwayFromZero;
import 'accounting/models.dart' show PeriodLockedException;
import 'accounting/repository.dart';
import 'accounting/tx_form_spec.dart' show labelTransaksi, pesanPeriodeTerkunci;
import 'transaction_model.dart';
import 'form_finance_page.dart';

class ListFinancePage extends StatefulWidget {
  const ListFinancePage({super.key});

  @override
  State<ListFinancePage> createState() => _ListFinancePageState();
}

class _ListFinancePageState extends State<ListFinancePage> {
  final AccountingRepository _repo = AccountingRepository.instance;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  double _totalSaldo = 0;
  double _pemasukan = 0;
  double _pengeluaran = 0;
  
  final Color polbanBlue = const Color(0xFF1E549F);
  final Color polbanDarkBlue = const Color(0xFF153E75);

  @override
  void initState() {
    super.initState();
    _refreshTransactions();
  }

  void _refreshTransactions() async {
    setState(() => _isLoading = true);
    final data = await _repo.transactions();
    final kas = (await _repo.loadReport(asOf: DateTime.now())).kas;

    if (mounted) {
      setState(() {
        _transactions = data;
        _pemasukan = kas.masuk.toDouble();
        _pengeluaran = kas.keluar.toDouble();
        _totalSaldo = kas.saldo.toDouble();
        _isLoading = false;
      });
    }
  }

  String _fmtUang(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  
  String _fmtDetail(int amount, int? qty) {
    if (qty == null || qty == 0 || amount == 0) return "";
    final price = roundHalfAwayFromZero(amount, qty);
    final fmtPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);
    return "(@ $fmtPrice x $qty)";
  }

  String _fmtTanggal(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) { return dateStr; }
  }

  String _label(TransactionModel t) => labelTransaksi(t);

  void _showDeleteDialog(TransactionModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Hapus Transaksi?"),
        content: Text("Yakin ingin menghapus ${_label(item)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await _repo.deleteTransaction(item.id!);
              } on PeriodLockedException catch (e) {
                messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text(pesanPeriodeTerkunci(e))));
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text("Tidak bisa dihapus: transaksi dirujuk retur/pelunasan lain.")));
              }
              _refreshTransactions();
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Keuangan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: polbanBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // HEADER CARD (FULL BLUE)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [polbanBlue, polbanDarkBlue]),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: polbanBlue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                const Text("Total Kas Saat Ini", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(_fmtUang(_totalSaldo), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      _summaryItem(Icons.arrow_downward, Colors.lightGreenAccent, "Pemasukan", _pemasukan),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _summaryItem(Icons.arrow_upward, Colors.redAccent, "Pengeluaran", _pengeluaran),
                    ],
                  ),
                )
              ],
            ),
          ),

          // LIST TRANSAKSI
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: polbanBlue))
                : _transactions.isEmpty
                    ? Center(child: Text("Belum ada transaksi", style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 25, 20, 80),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final item = _transactions[index];
                          bool isMasuk = item.arahKas > 0;
                          bool isNonTunai = item.arahKas == 0;
                          Color statusColor = isNonTunai ? Colors.orange : (isMasuk ? Colors.green : Colors.redAccent);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              borderRadius: BorderRadius.circular(18), 
                              boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: Icon(isNonTunai ? Icons.history_edu : (isMasuk ? Icons.arrow_downward : Icons.arrow_upward), color: statusColor, size: 22),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_label(item), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3436))),
                                        if (item.perluDitinjau)
                                          Text("Perlu ditinjau: ${item.reviewNote ?? ''}", style: const TextStyle(color: Colors.orange, fontSize: 11)),
                                        if (item.qty != null && item.qty! > 0)
                                          Text(_fmtDetail(item.amount, item.qty), style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontStyle: FontStyle.italic)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTanggal(item.date), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("${isMasuk ? '+' : '-'} ${_fmtUang(item.amount.toDouble()).replaceAll('Rp ', '')}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: statusColor)),
                                      const SizedBox(height: 5),
                                      Row(children: [
                                        GestureDetector(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => FormFinancePage(transaction: item))); _refreshTransactions(); }, child: Icon(Icons.edit, size: 18, color: Colors.grey[400])),
                                        const SizedBox(width: 12),
                                        GestureDetector(onTap: () => _showDeleteDialog(item), child: Icon(Icons.delete, size: 18, color: Colors.red[200])),
                                      ])
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: polbanBlue, // GANTI JADI BIRU
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Catat Transaksi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const FormFinancePage()));
          _refreshTransactions();
        },
      ),
    );
  }

  Widget _summaryItem(IconData icon, Color color, String label, double value) {
    return Expanded(
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(_fmtUang(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
        ],
      ),
    );
  }
}