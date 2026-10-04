// Inventaris: tambah/ubah barang. Satu kolom; pilihan berupa tombol besar, bukan
// dropdown kecil. Nilai yang disimpan sama dengan layar lama (lihat inventaris_data.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'asset_model.dart';
import 'inventaris_data.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

Future<String?> _pilihFotoAplikasi(ImageSource sumber) async =>
    (await ImagePicker().pickImage(source: sumber, imageQuality: 50))?.path;

class FormAssetPage extends StatefulWidget {
  const FormAssetPage({super.key, this.asset, this.sumber, this.kelompokAwal, this.hariIni, this.pilihFoto});

  /// null = barang baru.
  final AssetModel? asset;
  final SumberInventaris? sumber;

  /// Kelompok terpilih untuk barang baru (mis. kelompok yang sedang dibuka di daftar).
  final String? kelompokAwal;

  /// Pengganti "sekarang" (tes); null = DateTime.now().
  final DateTime? hariIni;

  /// Pengganti pemilih foto (tes); hasil = path file atau null bila batal.
  final Future<String?> Function(ImageSource sumber)? pilihFoto;

  @override
  State<FormAssetPage> createState() => _FormAssetPageState();
}

class _FormAssetPageState extends State<FormAssetPage> {
  late final SumberInventaris _sumber = widget.sumber ?? SumberInventaris.instance;
  final _nama = TextEditingController();
  final _jumlah = TextEditingController();
  final _keterangan = TextEditingController();

  late String _kelompok;
  String? _jenis;
  late String _satuan;
  String _kondisi = kondisiInventaris.first;
  String? _kepemilikan;
  final Set<String> _fungsiLahan = {};
  String _foto = '';
  Map<String, String> _salah = {};
  bool _menyimpan = false;

  bool get _ubah => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _kelompok = a?.kategori ?? widget.kelompokAwal ?? kelompokInventaris.first.nilai;
    _satuan = kelompokDari(_kelompok).satuanAwal;
    if (a != null) {
      if (kelompokDari(a.kategori).jenis.contains(a.nama)) {
        _jenis = a.nama;
      } else {
        _jenis = jenisLainnya;
        _nama.text = a.nama;
      }
      _jumlah.text = '${a.jumlah}';
      _keterangan.text = a.deskripsi;
      _satuan = a.satuan ?? _satuan;
      _kondisi = a.kondisi;
      _kepemilikan = a.statusKepemilikan;
      if (a.fungsiLahan case final f? when f.isNotEmpty) _fungsiLahan.addAll(f.split(', '));
      _foto = a.imagePath;
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  bool get _asetTetap => _kelompok == 'Aset Tetap';

  Future<void> _ambilFoto(ImageSource s) async {
    final path = await (widget.pilihFoto ?? _pilihFotoAplikasi)(s);
    if (path != null && mounted) setState(() => _foto = path);
  }

  Future<void> _simpan() async {
    final salah = <String, String>{
      if (_jenis == null) 'jenis': 'Pilih jenisnya',
      if (_jenis == jenisLainnya && _nama.text.trim().isEmpty) 'nama': 'Nama barang wajib diisi',
      if (int.tryParse(_jumlah.text) == null) 'jumlah': 'Jumlah wajib diisi dengan angka',
    };
    setState(() => _salah = salah);
    if (salah.isNotEmpty) return;
    final lama = widget.asset;
    final now = widget.hariIni ?? DateTime.now();
    final barang = AssetModel(
      id: lama?.id,
      nama: _jenis == jenisLainnya ? _nama.text.trim() : _jenis!,
      kategori: _kelompok,
      jumlah: int.parse(_jumlah.text),
      deskripsi: _keterangan.text.trim(),
      imagePath: _foto,
      date: lama?.date ?? isoTanggal(now),
      kondisi: _kondisi,
      satuan: _satuan,
      expiredDate: lama?.expiredDate ?? '',
      usageForTernak: lama?.usageForTernak,
      usageDuration: lama?.usageDuration,
      statusKepemilikan: _asetTetap ? _kepemilikan : null,
      fungsiLahan: _asetTetap && _fungsiLahan.isNotEmpty
          ? fungsiLahanInventaris.where(_fungsiLahan.contains).join(', ')
          : null,
    );
    setState(() => _menyimpan = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (_ubah) {
        await _sumber.ubah(barang);
      } else {
        await _sumber.tambah(barang);
      }
      messenger.showSnackBar(SnackBar(content: Text(_ubah ? 'Perubahan tersimpan.' : 'Barang tersimpan.')));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      await tampilkanPesan(context, judul: 'Tidak bisa disimpan', isi: '$e', gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final k = kelompokDari(_kelompok);
    final adaFoto = _foto.isNotEmpty && File(_foto).existsSync();
    const jarak = SizedBox(height: 20);
    return Scaffold(
      appBar: AppBar(title: Text(_ubah ? 'Ubah barang' : 'Tambah barang')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TombolUtama(
            label: _menyimpan ? 'Menyimpan...' : 'Simpan',
            ikon: Icons.save,
            onPressed: _menyimpan ? null : _simpan,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_salah.isNotEmpty) ...[
            BannerPeringatan(
              judul: '${_salah.length} isian perlu diperbaiki',
              isi: 'Lihat tulisan merah di bawah isian.',
              nada: Nada.error,
            ),
            jarak,
          ],
          PilihanTunggal<String>(
            label: 'Kelompok',
            opsi: [for (final g in kelompokInventaris) OpsiPilihan(g.nilai, g.label, keterangan: g.keterangan)],
            nilai: _kelompok,
            onChanged: (v) => setState(() {
              if (v == _kelompok) return;
              _kelompok = v;
              _jenis = null;
              _satuan = kelompokDari(v).satuanAwal;
            }),
          ),
          jarak,
          PilihanTombol<String>(
            label: 'Jenis',
            opsi: [for (final j in [...k.jenis, jenisLainnya]) OpsiPilihan(j, j)],
            terpilih: {?_jenis},
            errorText: _salah['jenis'],
            onPilih: (v) => setState(() => _jenis = v),
          ),
          if (_jenis == jenisLainnya) ...[
            jarak,
            LabelIsian(
              label: 'Nama barang',
              child: TextField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(errorText: _salah['nama'], errorMaxLines: 10),
              ),
            ),
          ],
          jarak,
          LabelIsian(
            label: 'Jumlah',
            child: TextField(
              controller: _jumlah,
              keyboardType: TextInputType.number,
              style: t.titleMedium,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(suffixText: _satuan, errorText: _salah['jumlah'], errorMaxLines: 10),
            ),
          ),
          jarak,
          PilihanTombol<String>(
            label: 'Satuan',
            opsi: [for (final s in satuanInventaris) OpsiPilihan(s, s)],
            terpilih: {_satuan},
            onPilih: (v) => setState(() => _satuan = v),
          ),
          jarak,
          PilihanTombol<String>(
            label: 'Kondisi',
            opsi: [for (final s in kondisiInventaris) OpsiPilihan(s, s)],
            terpilih: {_kondisi},
            onPilih: (v) => setState(() => _kondisi = v),
          ),
          if (_asetTetap) ...[
            jarak,
            PilihanTombol<String>(
              label: 'Status kepemilikan (boleh kosong)',
              opsi: [for (final s in kepemilikanInventaris) OpsiPilihan(s, s)],
              terpilih: {?_kepemilikan},
              onPilih: (v) => setState(() => _kepemilikan = _kepemilikan == v ? null : v),
            ),
            jarak,
            PilihanTombol<String>(
              label: 'Fungsi lahan (boleh pilih lebih dari satu)',
              opsi: [for (final s in fungsiLahanInventaris) OpsiPilihan(s, s)],
              terpilih: _fungsiLahan,
              onPilih: (v) => setState(() => _fungsiLahan.contains(v) ? _fungsiLahan.remove(v) : _fungsiLahan.add(v)),
            ),
          ],
          jarak,
          LabelIsian(
            label: 'Keterangan (boleh kosong)',
            child: TextField(
              controller: _keterangan,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
            ),
          ),
          jarak,
          Text('Foto (boleh kosong)', style: t.titleSmall),
          const SizedBox(height: 8),
          if (adaFoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_foto), height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            TombolKedua(
                label: 'Ambil foto',
                ikon: Icons.photo_camera,
                lebarPenuh: false,
                onPressed: () => _ambilFoto(ImageSource.camera)),
            TombolKedua(
                label: 'Pilih dari galeri',
                ikon: Icons.photo_library,
                lebarPenuh: false,
                onPressed: () => _ambilFoto(ImageSource.gallery)),
            if (_foto.isNotEmpty)
              TombolKedua(
                  label: 'Hapus foto',
                  ikon: Icons.hide_image,
                  lebarPenuh: false,
                  onPressed: () => setState(() => _foto = '')),
          ]),
          if (!adaFoto && _foto.isNotEmpty)
            Text('File foto tidak ditemukan di HP.', style: t.bodySmall!.copyWith(color: Warna.teksSekunder)),
        ],
      ),
    );
  }
}
