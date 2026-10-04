// Form transaksi per tipe. Field, label, wajib/opsional, dan validasi berasal dari
// tabel lib/accounting/tx_form_spec.dart; halaman ini hanya merender (Fase 1:
// widget Material bawaan, tampilan dirombak di Fase 3).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'accounting/tx_form_spec.dart';
import 'transaction_model.dart';

class FormFinancePage extends StatefulWidget {
  /// null = catat baru (mulai dari layar "Apa yang terjadi?").
  final TransactionModel? transaction;
  const FormFinancePage({super.key, this.transaction});

  @override
  State<FormFinancePage> createState() => _FormFinancePageState();
}

class _FormFinancePageState extends State<FormFinancePage> {
  final _repo = AccountingRepository.instance;
  final _fmtTanggal = DateFormat('yyyy-MM-dd');

  TxTypeFormSpec? _spec;
  final Map<FieldKey, Object?> _values = {};
  final Map<FieldKey, TextEditingController> _ctl = {};
  Map<FieldKey, String> _errors = {};
  List<RefOption> _piutang = [], _retur = [];
  bool _loading = true, _saving = false;

  bool get _isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final t = widget.transaction;
    final ref = await _repo.rujukan(kecuali: t?.id);
    FixedAssetModel? asset;
    if (t?.assetId != null) asset = await _repo.fixedAssetById(t!.assetId!);
    if (!mounted) return;
    setState(() {
      _piutang = ref.piutang;
      _retur = ref.retur;
      if (t != null) _pilih(specFor(t), valuesFrom(t, asset: asset));
      _loading = false;
    });
  }

  void _pilih(TxTypeFormSpec spec, [Map<FieldKey, Object?>? awal]) {
    _spec = spec;
    _errors = {};
    _values
      ..clear()
      ..[FieldKey.tanggal] = _fmtTanggal.format(DateTime.now())
      ..[FieldKey.sumberBayar] = PaymentSource.kas;
    if (awal != null) _values.addAll(awal);
    for (final c in _ctl.values) {
      c.dispose();
    }
    _ctl.clear();
    for (final f in spec.fields) {
      final kind = f.key.kind;
      if (kind == FieldKind.uang || kind == FieldKind.jumlah || kind == FieldKind.teks) {
        final v = _values[f.key];
        _ctl[f.key] = TextEditingController(
            text: v == null || (kind != FieldKind.teks && v is! int)
                ? '' // kosong atau nilai khusus (mis. tidak disusutkan)
                : (kind == FieldKind.uang ? _ribuan(v as int) : '$v'));
      }
    }
  }

  Map<int, RefOption> get _rujukanMap => {
        for (final r in [..._piutang, ..._retur]) r.id: r,
      };

  FormInput get _input => FormInput(_values, rujukan: _rujukanMap);

  Future<void> _simpan() async {
    final spec = _spec!;
    final errors = validateForm(spec, _input);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final draft = buildDraft(spec, _input, id: widget.transaction?.id);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final int id;
      if (_isEdit) {
        await _repo.updateDraft(draft);
        id = draft.tx.id!;
      } else {
        id = await _repo.insertDraft(draft);
      }
      final tersimpan = await _repo.transactionById(id);
      messenger.showSnackBar(SnackBar(
        duration: Duration(seconds: tersimpan?.perluDitinjau == true ? 8 : 3),
        content: Text(tersimpan?.perluDitinjau == true
            ? 'Tersimpan, tetapi ditandai PERLU DITINJAU dan belum dihitung di laporan: '
                '${tersimpan!.reviewNote}'
            : 'Transaksi tersimpan.'),
      ));
      navigator.pop(true);
    } on PeriodLockedException catch (e) {
      _gagal(pesanPeriodeTerkunci(e));
    } catch (e) {
      _gagal('Gagal menyimpan: $e');
    }
  }

  void _gagal(String pesan) {
    if (!mounted) return;
    setState(() => _saving = false);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tidak bisa disimpan'),
        content: Text(pesan),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Scaffold(
      appBar: AppBar(
        title: Text(spec == null
            ? 'Apa yang terjadi?'
            : (_isEdit ? 'Ubah: ${spec.label}' : spec.label)),
        leading: spec != null && !_isEdit
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _spec = null),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (spec == null ? _pilihTipe() : _form(spec)),
    );
  }

  Widget _pilihTipe() {
    final specs = [...txFormSpecs.values, returFormSpec];
    return ListView.separated(
      itemCount: specs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = specs[i];
        final tanpaRujukan = (s.retur && _retur.isEmpty) ||
            (s.type == TxType.terimaPiutang && _piutang.isEmpty);
        return ListTile(
          enabled: s.manual && !tanpaRujukan,
          title: Text(s.label),
          subtitle: Text(s.otomatis ??
              (tanpaRujukan ? 'Belum ada transaksi yang bisa dipilih' : (s.penjelasan ?? ''))),
          trailing: s.manual ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
          onTap: () => setState(() => _pilih(s)),
        );
      },
    );
  }

  Widget _form(TxTypeFormSpec spec) {
    if (!spec.manual) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(spec.otomatis!));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (spec.penjelasan != null)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(spec.penjelasan!)),
        for (final f in spec.fields)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
        if (spec.retur && _isEdit)
          const Text('Transaksi asal retur tidak bisa diganti; hapus lalu catat retur baru.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _simpan,
          child: Text(_isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN TRANSAKSI'),
        ),
      ],
    );
  }

  InputDecoration _dec(FieldSpec f) => InputDecoration(
        labelText: f.wajib ? f.label : '${f.label} (opsional)',
        hintText: f.hint,
        helperText: f.hint,
        helperMaxLines: 2,
        errorText: _errors[f.key],
        border: const OutlineInputBorder(),
      );

  Widget _field(FieldSpec f) {
    switch (f.key.kind) {
      case FieldKind.tanggal:
        final v = _values[f.key] as String?;
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: parseTanggal(v) ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _values[f.key] = _fmtTanggal.format(picked));
          },
          child: InputDecorator(
            decoration: _dec(f).copyWith(
              suffixIcon: v != null && !f.wajib
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _values[f.key] = null))
                  : const Icon(Icons.calendar_today),
            ),
            child: Text(v ?? '-'),
          ),
        );
      case FieldKind.uang:
      case FieldKind.jumlah:
        final uang = f.key.kind == FieldKind.uang;
        int? angka() => int.tryParse(_ctl[f.key]!.text.replaceAll('.', ''));
        final khusus = f.pilihan.any((p) => p.value == _values[f.key]);
        final input = TextField(
          controller: _ctl[f.key],
          enabled: !khusus,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
            if (uang) _RibuanFormatter(),
          ],
          decoration: _dec(f).copyWith(prefixText: uang ? 'Rp ' : null),
          onChanged: (s) => _values[f.key] = angka(),
        );
        if (f.pilihan.isEmpty) return input;
        // Nilai khusus pengganti angka (umur manfaat: tidak disusutkan/tanah).
        return Column(children: [
          input,
          for (final p in f.pilihan)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.label),
              value: _values[f.key] == p.value,
              onChanged: (c) => setState(() => _values[f.key] = c == true ? p.value : angka()),
            ),
        ]);
      case FieldKind.teks:
        return TextField(
          controller: _ctl[f.key],
          decoration: _dec(f),
          onChanged: (s) => _values[f.key] = s,
        );
      case FieldKind.pilihan:
        return DropdownButtonFormField<Object>(
          initialValue: _values[f.key],
          isExpanded: true,
          decoration: _dec(f),
          items: [
            for (final p in f.pilihan) DropdownMenuItem(value: p.value, child: Text(p.label)),
          ],
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldKind.rujukan:
        final opsi = f.key == FieldKey.rujukanPiutang ? _piutang : _retur;
        final terkunci = _isEdit && f.key == FieldKey.transaksiAsal;
        return DropdownButtonFormField<int>(
          initialValue: _values[f.key] as int?,
          isExpanded: true,
          decoration: _dec(f),
          items: [
            for (final r in opsi)
              DropdownMenuItem(
                value: r.id,
                child: Text('${r.label} (sisa ${formatRupiah(r.sisa)})',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: terkunci ? null : (v) => setState(() => _values[f.key] = v),
        );
    }
  }

  static String _ribuan(int v) => NumberFormat.decimalPattern('id_ID').format(v);
}

/// Pemisah ribuan (titik) untuk bilangan bulat Rupiah, tanpa double.
class _RibuanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _FormFinancePageState._ribuan(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
