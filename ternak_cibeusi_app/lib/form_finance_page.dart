import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';

class FormFinancePage extends StatefulWidget {
  final TransactionModel? transaction; 
  const FormFinancePage({Key? key, this.transaction}) : super(key: key);

  @override
  State<FormFinancePage> createState() => _FormFinancePageState();
}

class _FormFinancePageState extends State<FormFinancePage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _priceController = TextEditingController(); 
  final TextEditingController _qtyController = TextEditingController();   
  final TextEditingController _totalController = TextEditingController(); 
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String _selectedType = 'IN'; 
  String _selectedCategory = 'Jual Hasil Ternak Tunai'; 
  
  final List<String> _incomeCategories = ['Jual Hasil Ternak Tunai', 'Jual Hasil Ternak Kredit', 'Terima Pelunasan Piutang', 'Setor Modal Pribadi', 'Terima Pinjaman (Utang)', 'Pendapatan Lain-lain'];
  final List<String> _expenseCategories = ['Beli Pakan Tunai', 'Beli Obat & Vitamin', 'Beli Ternak/DOC', 'Beli Perlengkapan Kandang', 'Beli Peralatan Kandang', 'Bayar Utang / Cicilan', 'Biaya Listrik & Air', 'Biaya Tenaga Kerja', 'Biaya Perawatan Kandang', 'Biaya Lain-lain', 'Prive (Ambil Uang)', 'Pemakaian Pakan (Stok)', 'Pemakaian Obat (Stok)', 'Biaya DOC (HPP saat Panen)'];

  final Color polbanBlue = const Color(0xFF1E549F); // Warna Biru Konsisten

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _qtyController.text = widget.transaction!.qty?.toString() ?? '1';
      _totalController.text = _fmt(widget.transaction!.amount.toDouble());
      _descController.text = widget.transaction!.description;
      _dateController.text = widget.transaction!.date;
    } else {
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  void _calculateTotal() {
    String cleanPrice = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    double price = double.tryParse(cleanPrice) ?? 0;
    int qty = int.tryParse(_qtyController.text) ?? 0;
    _totalController.text = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(price * qty);
  }

  String _fmt(double val) => NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(val);

  // DB v2 butuh tipe transaksi eksplisit (tx_type). Form kategori lama tidak
  // dipetakan; penyimpanan dinonaktifkan sampai form tipe transaksi (sesi berikutnya).
  void _saveTransaction() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Pencatatan sementara dinonaktifkan: form tipe transaksi baru sedang disiapkan.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.transaction != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? "Edit Transaksi" : "Catat Transaksi", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: polbanBlue, // GANTI JADI BIRU
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Expanded(child: _typeButton("Pemasukan", 'IN', Colors.green)),
                    const SizedBox(width: 5),
                    Expanded(child: _typeButton("Pengeluaran", 'OUT', Colors.redAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              _label("Kategori"),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                items: (_selectedType == 'IN' ? _incomeCategories : _expenseCategories).map((String category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Harga Satuan (Rp)"),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                          onChanged: (_) => _calculateTotal(),
                          decoration: _inputDecoration(prefix: "Rp "),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Jumlah"),
                        TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => _calculateTotal(),
                          decoration: _inputDecoration(hint: "1"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _label("Total Nominal (Otomatis)"),
              TextFormField(
                controller: _totalController,
                readOnly: true,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: polbanBlue),
                decoration: _inputDecoration(prefix: "Rp ", fillColor: const Color(0xFFE3F2FD)),
                validator: (val) => val!.isEmpty || val == '0' ? "Nominal tidak boleh 0" : null,
              ),

              const SizedBox(height: 20),
              _label("Tanggal"),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: _inputDecoration(icon: Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                },
              ),
              const SizedBox(height: 15),
              _label("Catatan"),
              TextFormField(controller: _descController, decoration: _inputDecoration(hint: "Opsional...")),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: polbanBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 4), // GANTI JADI BIRU
                  onPressed: _saveTransaction,
                  child: Text(isEdit ? "SIMPAN PERUBAHAN" : "SIMPAN TRANSAKSI", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String label, String value, Color color) {
    bool isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() { _selectedType = value; _selectedCategory = value == 'IN' ? _incomeCategories[0] : _expenseCategories[0]; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []),
        child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey))),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)));
  
  InputDecoration _inputDecoration({IconData? icon, String? prefix, String? hint, Color? fillColor}) {
    return InputDecoration(
      filled: true, fillColor: fillColor ?? const Color(0xFFF5F7FA),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: const Color(0xFF1E549F), width: 1.5)),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      prefixText: prefix, hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), ''); 
    double value = double.tryParse(cleanText) ?? 0;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    String newText = formatter.format(value).trim();
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}