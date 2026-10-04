// Inventaris: daftar barang non-keuangan (tabel `assets`, tidak masuk laporan).
// Sumber data bisa diganti (tes); nilai yang disimpan sama dengan layar lama
// sehingga data lama tetap terbaca. Skema DB tidak berubah.
import 'package:sqflite/sqflite.dart';

import 'asset_model.dart';
import 'database/database_helper.dart';

class SumberInventaris {
  SumberInventaris(this._open);
  final Future<Database> Function() _open;

  static final SumberInventaris instance = SumberInventaris(() => DatabaseHelper.instance.database);

  Future<List<AssetModel>> semua() async {
    final db = await _open();
    final rows = await db.query('assets', orderBy: 'date DESC, id DESC');
    return rows.map(AssetModel.fromMap).toList();
  }

  Future<AssetModel?> byId(int id) async {
    final db = await _open();
    final rows = await db.query('assets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AssetModel.fromMap(rows.single);
  }

  Future<int> tambah(AssetModel a) async => (await _open()).insert('assets', a.toMap()..remove('id'));

  Future<void> ubah(AssetModel a) async =>
      (await _open()).update('assets', a.toMap(), where: 'id = ?', whereArgs: [a.id]);

  Future<void> hapus(int id) async => (await _open()).delete('assets', where: 'id = ?', whereArgs: [id]);
}

/// Kelompok inventaris: nilai tersimpan (sama dengan data lama) dan label layar.
class KelompokInventaris {
  const KelompokInventaris(this.nilai, this.label, this.keterangan, this.jenis, this.satuanAwal);
  final String nilai;
  final String label;
  final String keterangan;
  final List<String> jenis;
  final String satuanAwal;
}

const kelompokInventaris = [
  KelompokInventaris('Ternak', 'Ternak', 'Ayam, bebek, domba, dan hewan lain',
      ['Ayam Broiler', 'Ayam Petelur', 'Ayam Kampung', 'Bebek', 'Puyuh', 'Domba'], 'Ekor'),
  KelompokInventaris('Operasional Habis Pakai', 'Barang habis pakai', 'Pakan, vitamin, vaksin, sekam',
      ['Pakan Starter', 'Pakan Finisher', 'Vitamin', 'Vaksin', 'Desinfektan', 'Sekam'], 'Karung'),
  KelompokInventaris('Aset Tetap', 'Kandang, alat & lahan', 'Barang tahan lama dan tanah',
      ['Kandang', 'Gudang Pakan', 'Mesin Giling', 'Tempat Minum Otomatis', 'Pemanas (Gasolec)', 'Lahan'], 'Unit'),
];

KelompokInventaris kelompokDari(String nilai) =>
    kelompokInventaris.firstWhere((k) => k.nilai == nilai, orElse: () => kelompokInventaris.first);

const jenisLainnya = 'Lainnya';
const satuanInventaris = ['Ekor', 'Karung', 'Kg', 'Liter', 'Botol', 'Pcs', 'Unit', 'Set', 'Paket', 'm2', 'ha', 'tumbak'];
const kondisiInventaris = ['Baik', 'Rusak Ringan', 'Rusak Berat', 'Perlu Perbaikan'];
const kepemilikanInventaris = ['Hak Milik', 'Sewa', 'Hak Milik dan Sewa'];
const fungsiLahanInventaris = ['Peternakan', 'Pertanian', 'Perkebunan'];
