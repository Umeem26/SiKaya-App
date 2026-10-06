// Detail satu catatan dengan tombol "Ubah" dan "Hapus" berlabel (UI-PLAN.md 3.3).
// Catatan otomatis atau yang sudah ditutup buku: panel info dengan penjelasan,
// bukan tombol yang pasti ditolak.
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'accounting/models.dart';
import 'accounting/repository.dart';
import 'accounting/tx_form_spec.dart';
import 'form_finance_page.dart';
import 'transaction_model.dart';
import 'ui/alasan.dart';
import 'ui/item_catatan.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class DetailCatatanPage extends StatefulWidget {
  const DetailCatatanPage({super.key, required this.catatan, this.repo});
  final TransactionModel catatan;
  final AccountingRepository? repo;

  @override
  State<DetailCatatanPage> createState() => _DetailCatatanPageState();
}

class _DetailCatatanPageState extends State<DetailCatatanPage> {
  late final AccountingRepository _repo = widget.repo ?? AccountingRepository.instance;
  late TransactionModel _c = widget.catatan;
  FixedAssetModel? _aset;

  /// Tanggal tutup buku terakhir; [_kunciDimuat] false = belum dibaca (tombol belum ditampilkan).
  DateTime? _ditutupSampai;
  bool _kunciDimuat = false;

  @override
  void initState() {
    super.initState();
    _muatAset();
    _muatKunci();
  }

  Future<void> _muatAset() async {
    final id = _c.assetId;
    final a = id == null ? null : await _repo.fixedAssetById(id);
    if (mounted) setState(() => _aset = a);
  }

  Future<void> _muatKunci() async {
    DateTime? k;
    try {
      k = await _repo.lockedUntil();
    } catch (_) {} // gagal membaca: tombol tetap tampil, penolakan tetap dijaga repository
    if (mounted) {
      setState(() {
        _ditutupSampai = k;
        _kunciDimuat = true;
      });
    }
  }

  Future<void> _ubah() async {
    final berubah = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => FormFinancePage(transaction: _c, repo: widget.repo)));
    if (berubah != true || !mounted) return;
    final baru = await _repo.transactionById(_c.id!);
    if (!mounted) return;
    if (baru == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _c = baru);
    await _muatAset();
  }

  Future<void> _hapus() async {
    final ikutAset = hapusIkutAset(_c);
    final ya = await tanyaKonfirmasi(
      context,
      judul: ikutAset ? 'Hapus catatan dan aset tetapnya?' : 'Hapus catatan ini?',
      isi: pesanHapus(_c, aset: _aset),
      aksi: 'Hapus',
      ikonAksi: Icons.delete_rounded,
      bahaya: true,
    );
    if (!ya || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.deleteTransaction(_c.id!);
      messenger.showSnackBar(const SnackBar(content: Text('Catatan dihapus.')));
      if (mounted) Navigator.pop(context, true);
    } on PeriodLockedException catch (e) {
      if (mounted) await tampilkanPesan(context, judul: 'Tidak bisa dihapus', isi: pesanPeriodeTerkunci(e), gagal: true);
    } on DatabaseException {
      if (mounted) {
        await tampilkanPesan(context,
            judul: 'Tidak bisa dihapus',
            isi: 'Catatan ini dipakai oleh catatan lain (retur atau pembayaran piutang). '
                'Hapus dulu catatan yang memakainya.',
            gagal: true);
      }
    }
  }

  /// Label pilihan dari spec (mis. jenis biaya, cara bayar); null bila tidak ada.
  String? _labelPilihan(TxTypeFormSpec spec, FieldKey k, Object? v) {
    if (v == null) return null;
    for (final p in spec.field(k)?.pilihan ?? const <Pilihan>[]) {
      if (p.value == v) return p.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _c;
    final spec = specFor(c);
    final nilai = nilaiCatatan(c);
    final ditutup = sudahDitutup(c.date, _ditutupSampai);
    final baris = <(String, String)>[
      ('Tanggal', tanggalPanjang(c.date)),
      ('Nilai', nilai ?? 'Dihitung otomatis dari harga rata-rata stok'),
      ('Uang kas', kataArah(c)),
      if (c.item != null) ('Barang', namaBarang(c.item!)),
      if (c.qty != null) ('Jumlah', '${c.qty} ${satuanBarang(c.item)}'.trim()),
      if (_labelPilihan(spec, FieldKey.jenisBeban, c.expenseKind) case final l?) ('Jenis biaya', l),
      if (_labelPilihan(spec, FieldKey.sumberBayar, c.paymentSource) case final l?) ('Cara bayar', l),
      if (c.refId != null) ('Pembayaran untuk', 'Catatan No. ${c.refId}'),
      if (c.reversalOf != null) ('Retur dari', 'Catatan No. ${c.reversalOf}'),
      if (_aset case final a?) ...[
        ('Nama aset', a.name),
        ('Umur manfaat', a.lifeMonths == null ? 'Tidak disusutkan' : '${a.lifeMonths} bulan'),
        if (a.readyDate != null) ('Mulai dipakai', tanggalPanjang(a.readyDate!)),
      ],
      if (c.description.isNotEmpty) ('Catatan', c.description),
      ('No. catatan', '${c.id}'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Detail catatan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(labelTransaksi(c), style: t.headlineSmall),
          if (ditutup) ...[
            const SizedBox(height: Jarak.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LencanaDitutup(
                  label: labelDitutup(_ditutupSampai!), onTap: () => jelaskanDitutup(context, _ditutupSampai!)),
            ),
          ],
          if (c.perluDitinjau) ...[
            const SizedBox(height: 12),
            BannerPeringatan(
              judul: 'Perlu dicek',
              isi: '${alasanPerluDicek(c.reviewNote)}. Catatan ini belum dihitung di laporan; '
                  'ubah bila salah isi, atau hapus.\n\nRincian: ${c.reviewNote ?? '-'}',
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (final (label, isi) in baris) BarisLaporan(label: label, nilai: isi),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          if (ditutup)
            PanelInfo(
              judul: 'Sudah ditutup buku',
              isi: 'Catatan sampai ${tanggalPanjang(isoTanggal(_ditutupSampai!))} dikunci saat tutup buku, '
                  'jadi tidak bisa diubah atau dihapus.',
              onInfo: () => jelaskanDitutup(context, _ditutupSampai!),
            )
          else if (_kunciDimuat) ...[
            if (spec.manual)
              TombolKedua(label: 'Ubah', ikon: Icons.edit_rounded, onPressed: _ubah)
            else
              PanelInfo(
                judul: 'Dicatat otomatis',
                isi: ringkasOtomatis(c.txType),
                onInfo: () => jelaskanOtomatis(context, c.txType),
              ),
            const SizedBox(height: 12),
            TombolBahaya(label: 'Hapus', ikon: Icons.delete_rounded, onPressed: _hapus),
          ],
        ],
      ),
    );
  }
}
