import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'accounting/repository.dart';
import 'transaction_model.dart';
import 'form_finance_page.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({Key? key}) : super(key: key);

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final AccountingRepository _repo = AccountingRepository.instance;
  
  // WARNA POLBAN
  final Color polbanBlue = const Color(0xFF1E549F);
  final Color polbanOrange = const Color(0xFFFA9C1B);
  
  List<TransactionModel> _transactions = [];
  double _totalSaldo = 0;
  double _pemasukan = 0;
  double _pengeluaran = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    setState(() => _isLoading = true);
    final data = await _repo.transactions();
    final kas = (await _repo.loadReport(asOf: DateTime.now())).kas;
    final double totalMasuk = kas.masuk.toDouble();
    final double totalKeluar = kas.keluar.toDouble();

    if (mounted) {
      setState(() {
        _transactions = data;
        _pemasukan = totalMasuk;
        _pengeluaran = totalKeluar;
        _totalSaldo = totalMasuk - totalKeluar;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  void _deleteData(int id) async {
    try {
      await _repo.deleteTransaction(id);
    } catch (_) {
      // dirujuk retur/pelunasan lain; baris tetap ada
    }
    _refreshData(); 
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Data yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteData(id);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Keuangan Peternakan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: polbanBlue, // BIRU POLBAN
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: polbanBlue))
        : Column(
        children: [
          // --- KARTU SALDO (HEADER) ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: polbanBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                 BoxShadow(color: polbanBlue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
              ]
            ),
            child: Column(
              children: [
                const Text('Total Saldo Saat Ini', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 5),
                Text(
                  _formatCurrency(_totalSaldo),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                // RINGKASAN MASUK / KELUAR
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pemasukan
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pemasukan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(_formatCurrency(_pemasukan),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      // Pengeluaran
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pengeluaran', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(_formatCurrency(_pengeluaran),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // --- LIST RIWAYAT ---
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("Belum ada transaksi", style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final item = _transactions[index];
                      final isMasuk = item.arahKas > 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMasuk ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isMasuk ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            item.category.isNotEmpty ? item.category : item.txType.code,
                            style: TextStyle(fontWeight: FontWeight.bold, color: polbanBlue),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item.date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if(item.description.isNotEmpty)
                                Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (isMasuk ? '+ ' : '- ') + _formatCurrency(item.amount.toDouble()),
                                style: TextStyle(
                                  color: isMasuk ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14
                                ),
                              ),
                              const SizedBox(width: 5),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400]),
                                onPressed: () => _confirmDelete(item.id!),
                              )
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
        backgroundColor: polbanBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Catat Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormFinancePage()),
          );
          if (result == true) {
            _refreshData();
          }
        },
      ),
    );
  }
}