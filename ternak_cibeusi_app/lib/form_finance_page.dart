// Catat kejadian (UI-PLAN.md bagian 3.2): layar "Apa yang terjadi?" berkelompok,
// lalu form satu kolom. Field, label, wajib/opsional, dan validasi berasal dari
// tabel lib/accounting/tx_form_spec.dart; halaman ini hanya merender.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accounting/engine.dart' show cashDirection;
import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'accounting/tx_form_spec.dart';
import 'transaction_model.dart';
import 'ui/item_catatan.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class KelompokCatat {
  const KelompokCatat(this.judul, this.pilihan);
  final String judul;
  final List<TxTypeFormSpec> pilihan;
}

TxTypeFormSpec _s(TxType t) => txFormSpecs[t]!;

/// Urutan layar "Apa yang terjadi?". Setiap spec muncul tepat sekali; yang
/// dicatat otomatis tetap tampil (nonaktif) beserta alasannya.
final kelompokCatat = [
  KelompokCatat('Jual & terima uang',
      [_s(TxType.penjualanTunai), _s(TxType.penjualanKredit), _s(TxType.terimaPiutang)]),
  KelompokCatat('Beli',
      [_s(TxType.beliPersediaanTunai), _s(TxType.beliPersediaanKredit), _s(TxType.beliAsetTetap)]),
  KelompokCatat('Pakai stok & ternak mati', [_s(TxType.pakaiPersediaan), _s(TxType.kematianTernak)]),
  KelompokCatat('Bayar biaya', [_s(TxType.bebanOperasional), _s(TxType.bebanBunga)]),
  KelompokCatat('Modal & pinjaman', [
    _s(TxType.setorModal),
    _s(TxType.prive),
    _s(TxType.terimaPinjaman),
    _s(TxType.bayarCicilanPokok),
  ]),
  const KelompokCatat('Koreksi (retur)', [returFormSpec]),
  KelompokCatat('Dicatat otomatis', [_s(TxType.penyusutan), _s(TxType.tutupBuku)]),
];

class FormFinancePage extends StatefulWidget {
  /// null = catat baru (mulai dari layar "Apa yang terjadi?").
  final TransactionModel? transaction;
  final AccountingRepository? repo;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;
  const FormFinancePage({super.key, this.transaction, this.repo, this.hariIni});

  @override
  State<FormFinancePage> createState() => _FormFinancePageState();
}

class _FormFinancePageState extends State<FormFinancePage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;

  TxTypeFormSpec? _spec;
  final Map<FieldKey, Object?> _values = {};
  final Map<FieldKey, TextEditingController> _ctl = {};
  final Map<FieldKey, GlobalKey> _kunci = {};
  Map<FieldKey, String> _errors = {};
  List<RefOption> _piutang = [], _retur = [];
  bool _loading = true, _saving = false;

  bool get _isEdit => widget.transaction != null;
  DateTime get _hariIni => widget.hariIni ?? DateTime.now();

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
      ..[FieldKey.tanggal] = isoTanggal(_hariIni)
      ..[FieldKey.sumberBayar] = PaymentSource.kas;
    if (awal != null) _values.addAll(awal);
    for (final c in _ctl.values) {
      c.dispose();
    }
    _ctl.clear();
    _kunci.clear();
    for (final f in spec.fields) {
      _kunci[f.key] = GlobalKey();
      final kind = f.key.kind;
      if (kind == FieldKind.uang || kind == FieldKind.jumlah || kind == FieldKind.teks) {
        final v = _values[f.key];
        _ctl[f.key] = TextEditingController(
            text: v == null || (kind != FieldKind.teks && v is! int)
                ? '' // kosong atau nilai khusus (mis. tidak disusutkan)
                : (kind == FieldKind.uang ? ribuan(v as int) : '$v'));
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
    if (errors.isNotEmpty) {
      // Gulir ke isian pertama yang salah (urutan error = urutan field).
      final ctx = _kunci[errors.keys.first]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
      return;
    }
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
      if (!mounted) return;
      if (tersimpan != null && tersimpan.perluDitinjau) {
        await tampilkanPesan(
          context,
          judul: 'Tersimpan, tetapi perlu dicek',
          isi: '${alasanPerluDicek(tersimpan.reviewNote)}.\n\n'
              'Catatan ini belum dihitung di laporan sampai diperbaiki. '
              'Buka Catatan, lalu ubah atau hapus.\n\nRincian: ${tersimpan.reviewNote}',
        );
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Perubahan tersimpan.' : 'Catatan tersimpan.'),
        ));
      }
      navigator.pop(true);
    } on PeriodLockedException catch (e) {
      await _gagal(pesanPeriodeTerkunci(e));
    } catch (e) {
      await _gagal('Terjadi kesalahan saat menyimpan: $e');
    }
  }

  Future<void> _gagal(String pesan) async {
    if (!mounted) return;
    setState(() => _saving = false);
    await tampilkanPesan(context, judul: 'Tidak bisa disimpan', isi: pesan, gagal: true);
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return PopScope(
      // Catat baru: tombol kembali dari form = kembali ke pilihan.
      canPop: spec == null || _isEdit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _spec = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(spec == null ? 'Apa yang terjadi?' : (_isEdit ? 'Ubah catatan' : 'Catat')),
        ),
        bottomNavigationBar: spec == null || !spec.manual
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TombolUtama(
                    label: _saving ? 'Menyimpan...' : (_isEdit ? 'Simpan perubahan' : 'Simpan'),
                    ikon: Icons.save_rounded,
                    onPressed: _saving ? null : _simpan,
                  ),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (spec == null ? _pilihTipe() : _form(spec)),
      ),
    );
  }

  String? _alasanNonaktif(TxTypeFormSpec s) {
    if (!s.manual) return s.otomatis;
    if (s.retur && _retur.isEmpty) return 'Belum ada catatan yang bisa diretur.';
    if (s.type == TxType.terimaPiutang && _piutang.isEmpty) {
      return 'Belum ada penjualan yang belum dibayar.';
    }
    return null;
  }

  /// Nada ubin per jenis: arah kas bila jelas (masuk hijau, keluar oranye tua), selain itu biru.
  Nada _nadaJenis(TxType? t) => t == null ? Nada.netral : nadaArah(cashDirection(t));

  Widget _pilihTipe() {
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const PageStorageKey('pilih-kejadian'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Pilih yang paling sesuai dengan kejadiannya.',
            style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        for (final k in kelompokCatat) ...[
          const SizedBox(height: Jarak.s24),
          JudulSeksi(k.judul),
          for (final s in k.pilihan) ...[
            const SizedBox(height: Jarak.s12),
            KartuPilihan(
              judul: s.label,
              penjelasan: s.penjelasan,
              alasanNonaktif: _alasanNonaktif(s),
              ikon: ikonJenis(s.type),
              nada: _nadaJenis(s.type),
              onTap: () => setState(() => _pilih(s)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _form(TxTypeFormSpec spec) {
    final t = Theme.of(context).textTheme;
    if (!spec.manual) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(spec.label, style: t.headlineSmall),
        const SizedBox(height: 12),
        BannerPeringatan(judul: 'Tidak bisa diubah di sini', isi: spec.otomatis!),
      ]);
    }
    // Kunci per jenis: form baru selalu mulai dari atas (tidak mewarisi gulir daftar pilihan).
    return ListView(
      key: ObjectKey(spec),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UbinIkon(ikonJenis(spec.type), nada: _nadaJenis(spec.type), ukuran: 52),
          const SizedBox(width: Jarak.s12),
          Expanded(child: Text(spec.label, style: t.titleLarge)),
        ]),
        if (spec.penjelasan != null) ...[
          const SizedBox(height: Jarak.s8),
          Text(spec.penjelasan!, style: t.bodyLarge!.copyWith(color: Warna.teksSekunder)),
        ],
        if (!_isEdit) ...[
          const SizedBox(height: 12),
          TombolKedua(
            label: 'Ganti pilihan',
            ikon: Icons.swap_horiz_rounded,
            onPressed: () => setState(() => _spec = null),
          ),
        ],
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          BannerPeringatan(
            judul: '${_errors.length} isian perlu diperbaiki',
            isi: 'Lihat tulisan merah di bawah isian.',
            nada: Nada.error,
          ),
        ],
        for (final f in spec.fields) ...[
          const SizedBox(height: 20),
          KeyedSubtree(key: _kunci[f.key], child: _field(spec, f)),
        ],
        if (spec.retur && _isEdit) ...[
          const SizedBox(height: 12),
          Text('Catatan asal retur tidak bisa diganti; hapus lalu catat retur baru.',
              style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
        ],
      ],
    );
  }

  String _label(FieldSpec f) => f.wajib ? f.label : '${f.label} (boleh kosong)';

  Widget _field(TxTypeFormSpec spec, FieldSpec f) {
    final err = _errors[f.key];
    switch (f.key.kind) {
      case FieldKind.tanggal:
        return InputTanggal(
          label: _label(f),
          nilai: _values[f.key] as String?,
          bolehKosong: !f.wajib,
          teksKosong: 'Belum diisi',
          helperText: f.hint,
          errorText: err,
          hariIni: _hariIni,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldKind.uang:
        return InputRupiah(
          label: _label(f),
          controller: _ctl[f.key]!,
          helperText: f.hint,
          errorText: err,
          onChanged: (v) => _values[f.key] = v,
        );
      case FieldKind.jumlah:
        int? angka() => int.tryParse(_ctl[f.key]!.text);
        final khusus = f.pilihan.any((p) => p.value == _values[f.key]);
        final satuan = f.key == FieldKey.umurBulan
            ? 'bulan'
            : satuanBarang((_values[FieldKey.item] as StockItem?) ?? spec.itemTetap);
        final input = TextField(
          controller: _ctl[f.key],
          enabled: !khusus,
          keyboardType: TextInputType.number,
          style: Theme.of(context).textTheme.titleMedium,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            helperText: f.hint,
            helperMaxLines: 10,
            errorText: err,
            errorMaxLines: 10,
            suffixText: satuan.isEmpty ? null : satuan,
          ),
          onChanged: (s) => _values[f.key] = angka(),
        );
        if (f.pilihan.isEmpty) return LabelIsian(label: _label(f), child: input);
        // Nilai khusus pengganti angka (umur manfaat: tidak disusutkan/tanah).
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LabelIsian(label: _label(f), child: input),
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
        final panjang = f.key == FieldKey.keterangan;
        return LabelIsian(label: _label(f), child: TextField(
          controller: _ctl[f.key],
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: panjang ? 4 : 2,
          decoration: InputDecoration(
            helperText: f.hint == 'Opsional' ? null : f.hint,
            helperMaxLines: 10,
            errorText: err,
            errorMaxLines: 10,
          ),
          onChanged: (s) => _values[f.key] = s,
        ));
      case FieldKind.pilihan:
        return PilihanTunggal<Object>(
          label: _label(f),
          opsi: [for (final p in f.pilihan) OpsiPilihan(p.value, p.label)],
          nilai: _values[f.key],
          errorText: err,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldKind.rujukan:
        final opsi = f.key == FieldKey.rujukanPiutang ? _piutang : _retur;
        final terkunci = _isEdit && f.key == FieldKey.transaksiAsal;
        return PilihanTunggal<int>(
          label: _label(f),
          opsi: [
            for (final r in opsi)
              OpsiPilihan(
                r.id,
                txFormSpecs[r.type]!.label,
                keterangan: '${tanggalPendek(r.date)} · ${rupiah(r.amount)} · '
                    'sisa ${rupiah(r.sisa)} · No. ${r.id}',
              ),
          ],
          nilai: _values[f.key] as int?,
          errorText: err,
          onChanged: terkunci ? null : (v) => setState(() => _values[f.key] = v),
        );
    }
  }
}
