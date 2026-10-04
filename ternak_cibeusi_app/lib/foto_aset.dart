// Foto aset tetap: file `foto_aset/aset_<id aset>_<id catatan beli>.jpg` di folder
// dokumen aplikasi. Tidak ada kolom DB (skema tidak berubah); id catatan beli ikut
// di nama file agar foto tidak menempel ke aset lain bila id aset terpakai ulang
// sesudah data dihapus/dipulihkan. Seperti foto inventaris, file ini tidak ikut cadangan.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SumberFotoAset {
  SumberFotoAset(this._folder);
  final Future<Directory?> Function() _folder;

  static final SumberFotoAset instance = SumberFotoAset(() async {
    final d = await getApplicationDocumentsDirectory();
    return Directory(p.join(d.path, 'foto_aset'));
  });

  /// Tanpa foto (tes widget: tidak ada path_provider).
  static final SumberFotoAset kosong = SumberFotoAset(() async => null);

  static String namaFile(int idAset, int? idBeli) => 'aset_${idAset}_${idBeli ?? 0}.jpg';

  Future<File?> _file(int idAset, int? idBeli) async {
    try {
      final d = await _folder();
      return d == null ? null : File(p.join(d.path, namaFile(idAset, idBeli)));
    } catch (_) {
      return null; // folder tidak tersedia: tampil tanpa foto
    }
  }

  /// File foto bila ada.
  Future<File?> foto(int idAset, int? idBeli) async {
    final f = await _file(idAset, idBeli);
    return f != null && await f.exists() ? f : null;
  }

  /// Salin [sumber] (hasil kamera/galeri) sebagai foto aset; mengganti yang lama.
  Future<File?> simpan(int idAset, int? idBeli, String sumber) async {
    final f = await _file(idAset, idBeli);
    if (f == null) return null;
    await f.parent.create(recursive: true);
    return File(sumber).copy(f.path);
  }

  Future<void> hapus(int idAset, int? idBeli) async {
    final f = await _file(idAset, idBeli);
    if (f != null && await f.exists()) await f.delete();
  }

  /// Hapus semua foto aset (dipakai "Hapus semua data").
  Future<void> hapusSemua() async {
    try {
      final d = await _folder();
      if (d != null && await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
