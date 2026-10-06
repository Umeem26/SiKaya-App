// Foto aset tetap: file `foto_aset/aset_<id aset>_<id catatan beli>.jpg` di folder
// dokumen aplikasi. Tidak ada kolom DB (skema tidak berubah); id catatan beli ikut
// di nama file agar foto tidak menempel ke aset lain bila id aset terpakai ulang
// sesudah data dihapus/dipulihkan. Foto inventaris disalin ke `foto_inventaris/`
// (path di kolom imagePath). Kedua folder ikut cadangan zip (database/backup.dart).
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Kompresi saat foto diambil: sisi terpanjang maks. 1280px, kualitas JPEG 80.
const fotoSisiMaks = 1280.0;
const fotoKualitas = 80;

/// Ambil foto dari kamera/galeri, sudah diperkecil dan dikompres; null = batal.
Future<String?> ambilFotoTerkompres(ImageSource sumber) async => (await ImagePicker().pickImage(
        source: sumber, maxWidth: fotoSisiMaks, maxHeight: fotoSisiMaks, imageQuality: fotoKualitas))
    ?.path;

Future<Directory> folderFotoAsetAplikasi() async =>
    Directory(p.join((await getApplicationDocumentsDirectory()).path, 'foto_aset'));

Future<Directory> folderFotoInventarisAplikasi() async =>
    Directory(p.join((await getApplicationDocumentsDirectory()).path, 'foto_inventaris'));

/// Salin foto inventaris [sumber] (file sementara pemilih foto) ke [folder]; path barunya.
Future<String> simpanFotoInventaris(String sumber, Directory folder, {DateTime? waktu}) async {
  await folder.create(recursive: true);
  final eks = p.extension(sumber).toLowerCase();
  final tujuan = p.join(folder.path, 'foto_${(waktu ?? DateTime.now()).microsecondsSinceEpoch}${eks.isEmpty ? '.jpg' : eks}');
  return (await File(sumber).copy(tujuan)).path;
}

class SumberFotoAset {
  SumberFotoAset(this._folder);
  final Future<Directory?> Function() _folder;

  static final SumberFotoAset instance = SumberFotoAset(folderFotoAsetAplikasi);

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
