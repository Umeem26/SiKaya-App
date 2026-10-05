// Cadangan zip (bagian 5): DB + foto aset tetap + foto inventaris + manifest.json.
// Ekspor lalu pulihkan mengembalikan laporan identik dan semua foto; zip rusak,
// manifest tak dikenal, dan jalur berbahaya ("../") ditolak tanpa mengubah data.
// File .db lama (tanpa foto) tetap bisa dipulihkan.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/accounting/repository.dart';
import 'package:ternak_cibeusi_app/asset_model.dart';
import 'package:ternak_cibeusi_app/database/backup.dart';
import 'package:ternak_cibeusi_app/database/database_helper.dart';
import 'package:ternak_cibeusi_app/database/schema.dart';
import 'package:ternak_cibeusi_app/foto_aset.dart';
import 'package:ternak_cibeusi_app/accounting/models.dart';
import 'package:ternak_cibeusi_app/transaction_model.dart';

import 'backup_test.dart' show sidikJari;
import 'closing_test.dart' show seedCampuran;
import 'helpers.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late String path;
  late Directory fotoAset, fotoInv, luar;
  Database? db;
  late AccountingRepository repo;
  late BackupService svc;

  Future<Database> open() async => db ??= await DatabaseHelper.openAppDatabase(path, databaseFactoryFfi);

  /// Laporan beberapa periode, transaksi, aset tetap, kunci periode, dan barang
  /// inventaris (tanpa imagePath: path foto memang berubah ke folder pulihan).
  Future<String> keadaan() async {
    final out = <String>[];
    for (final (from, asOf) in [(null, '2026-01-31'), ('2026-02-01', '2026-02-28'), ('2026-01-01', '2027-12-31')]) {
      final r = await repo.loadReport(asOf: d(asOf), from: from == null ? null : d(from));
      out.add('${sidikJari(r.report)} kas=${r.kas.masuk}/${r.kas.keluar}');
    }
    out.add((await repo.transactions()).map((t) => t.toMap().toString()).join());
    out.add((await repo.fixedAssets()).map((a) => a.toMap().toString()).join());
    out.add('${await repo.lockedUntil()}');
    out.add((await (await open()).query('assets', orderBy: 'id'))
        .map((r) => (Map.of(r)..remove('imagePath')).toString())
        .join());
    return out.join('\n');
  }

  /// Isi folder foto: "foto_aset/aset_1_2.jpg" -> isi.
  Map<String, String> isiFoto() => {
        for (final d in [fotoAset, fotoInv])
          if (d.existsSync())
            for (final f in d.listSync().whereType<File>())
              '${p.basename(d.path)}/${p.basename(f.path)}': base64Encode(f.readAsBytesSync()),
      };

  /// Foto inventaris per id barang (isi file yang ditunjuk imagePath).
  Future<Map<int, String?>> fotoBarang() async => {
        for (final r in await (await open()).query('assets', orderBy: 'id'))
          r['id'] as int: File(r['imagePath'] as String).existsSync()
              ? base64Encode(File(r['imagePath'] as String).readAsBytesSync())
              : null,
      };

  /// Semua file di bawah folder uji (untuk memastikan penolakan tidak menulis apa pun).
  Set<String> semuaFile() => dir.listSync(recursive: true).map((e) => e.path).toSet();

  File tulis(Directory d, String nama, List<int> isi) =>
      File(p.join(d.path, nama))..createSync(recursive: true)..writeAsBytesSync(isi);

  Future<int> barang(String nama, String imagePath) async => (await open()).insert(
      'assets',
      AssetModel(
              nama: nama,
              kategori: 'Peralatan',
              jumlah: 2,
              deskripsi: '',
              imagePath: imagePath,
              date: '2026-01-05',
              kondisi: 'Baik')
          .toMap());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sikaya_zip');
    path = p.join(dir.path, 'db', 'sikaya.db');
    fotoAset = Directory(p.join(dir.path, 'dokumen', 'foto_aset'));
    fotoInv = Directory(p.join(dir.path, 'dokumen', 'foto_inventaris'));
    luar = Directory(p.join(dir.path, 'cache'));
    repo = AccountingRepository(open, backup: () => DatabaseHelper.copyDatabaseFile(path, 'tutupbuku'));
    svc = BackupService(
      open: open,
      close: () async {
        await db?.close();
        db = null;
      },
      factory: () => databaseFactoryFfi,
      folderFotoAset: () async => fotoAset,
      folderFotoInventaris: () async => fotoInv,
    );
    await seedCampuran(repo);
    await repo.closeBook(d('2026-01-31'), today: d('2026-03-01'));
    // Foto aset tetap (nama dari foto_aset.dart) dan berkas lain yang tidak ikut.
    tulis(fotoAset, 'aset_1_0.jpg', List.generate(3000, (i) => i % 251));
    tulis(fotoAset, 'aset_2_5.jpg', List.generate(1500, (i) => (i * 7) % 256));
    tulis(fotoAset, 'catatan.txt', utf8.encode('bukan foto'));
    // Inventaris: satu foto di folder inventaris, satu di cache pemilih foto (versi lama), satu tanpa foto.
    await barang('Ember', tulis(fotoInv, 'foto_1.jpg', List.generate(800, (i) => (i * 3) % 256)).path);
    await barang('Terpal', tulis(luar, 'image_picker_123.png', List.generate(900, (i) => (i * 5) % 256)).path);
    await barang('Sekop', '');
  });
  tearDown(() async {
    await db?.close();
    db = null;
    await dir.delete(recursive: true);
  });

  test('nama file zip berstempel waktu dan versi skema', () {
    expect(backupZipFileName(DateTime(2026, 10, 4, 7, 5, 9)), 'SiKaya_cadangan_v${dbVersion}_20261004_070509.zip');
    expect(dbVersion, 2); // nama = SiKaya_cadangan_v2_<waktu>.zip
  });

  test('foto diambil terkompres (sisi terpanjang 1280px, kualitas 80); foto inventaris disalin ke foldernya',
      () async {
    expect((fotoSisiMaks, fotoKualitas), (1280.0, 80));
    final sumber = tulis(luar, 'image_picker_9.jpg', [4, 5, 6]);
    final baru = await simpanFotoInventaris(sumber.path, fotoInv, waktu: DateTime(2026, 3, 2));
    expect(p.isWithin(fotoInv.path, baru), isTrue);
    expect(File(baru).readAsBytesSync(), [4, 5, 6]);
  });

  test('isi zip: DB, foto aset, foto inventaris, manifest', () async {
    final file =
        await svc.exportZipTo(p.join(dir.path, backupZipFileName(DateTime(2026, 3, 2))), waktu: DateTime(2026, 3, 2, 8));
    final arsip = ZipDecoder().decodeBytes(File(file).readAsBytesSync());
    expect(arsip.files.map((f) => f.name).toSet(), {
      'sikaya.db',
      'manifest.json',
      'foto_aset/aset_1_0.jpg',
      'foto_aset/aset_2_5.jpg',
      'foto_inventaris/inv_1.jpg',
      'foto_inventaris/inv_2.png',
    });
    final manifest = jsonDecode(utf8.decode(arsip.findFile('manifest.json')!.content)) as Map;
    expect(manifest['format'], formatCadangan);
    expect(manifest['versiSkema'], dbVersion);
    expect(manifest['jumlahFoto'], {'aset': 2, 'inventaris': 2});
    expect(manifest['dibuat'], '2026-03-02T08:00:00.000');
    final isi = await svc.inspect(file);
    expect((isi.transaksi, isi.inventaris, isi.fotoAset, isi.fotoInventaris), (10, 3, 2, 2));
  });

  test('ekspor zip lalu pulihkan: laporan identik dan semua foto kembali', () async {
    final sebelum = await keadaan();
    final fotoSebelum = isiFoto()..remove('foto_aset/catatan.txt');
    final barangSebelum = await fotoBarang();
    expect(barangSebelum.values.whereType<String>(), hasLength(2));
    final file = await svc.exportZipTo(p.join(dir.path, backupZipFileName(DateTime.now())));

    // Data dan foto berubah sesudah ekspor.
    await repo.insertTransaction(const TransactionModel(txType: TxType.prive, amount: 100000, date: '2026-02-20'));
    File(p.join(fotoAset.path, 'aset_1_0.jpg')).deleteSync();
    tulis(fotoAset, 'aset_2_5.jpg', [1, 2, 3]);
    tulis(fotoAset, 'aset_9_9.jpg', [9, 9, 9]);
    fotoInv.deleteSync(recursive: true);
    await (await open()).delete('assets', where: 'name = ?', whereArgs: ['Sekop']);
    final berubah = await keadaan();
    final fotoBerubah = isiFoto();
    final barangBerubah = await fotoBarang();
    expect(berubah, isNot(sebelum));

    final hasil = await svc.restoreFrom(file);
    expect(hasil.dipulihkan.jumlahFoto, 4);
    expect(await keadaan(), sebelum);
    expect(isiFoto(), {
      ...fotoSebelum,
      // Foto inventaris kembali dengan nama per id; foto dari cache lama ikut dipindah ke folder inventaris.
      'foto_inventaris/inv_1.jpg': fotoSebelum['foto_inventaris/foto_1.jpg'],
      'foto_inventaris/inv_2.png': barangSebelum[2],
    }..remove('foto_inventaris/foto_1.jpg'));
    expect(await fotoBarang(), barangSebelum);
    expect(Directory('$path.pulihkan_foto').existsSync(), isFalse);
    expect(File('$path.pulihkan').existsSync(), isFalse);

    // Cadangan otomatis = kondisi sebelum dipulihkan, termasuk fotonya.
    expect(p.basename(hasil.cadanganOtomatis), allOf(contains('_backup_sebelumpulih_'), endsWith('.zip')));
    await svc.restoreFrom(hasil.cadanganOtomatis);
    expect(await keadaan(), berubah);
    Map<String, String> aset(Map<String, String> m) =>
        {for (final e in m.entries) if (e.key.startsWith('foto_aset/aset_')) e.key: e.value};
    expect(aset(isiFoto()), aset(fotoBerubah));
    expect(await fotoBarang(), barangBerubah);
  });

  test('file .db lama (tanpa foto) tetap bisa dipulihkan; foto di HP dibiarkan', () async {
    final sebelum = await keadaan();
    final lama = await svc.exportTo(p.join(dir.path, backupFileName(DateTime.now())));
    await repo.insertTransaction(const TransactionModel(txType: TxType.prive, amount: 100000, date: '2026-02-20'));
    final foto = isiFoto();
    final hasil = await svc.restoreFrom(lama);
    expect(hasil.dipulihkan.jumlahFoto, 0);
    expect(await keadaan(), sebelum);
    expect(isiFoto(), foto);
  });

  group('zip ditolak tanpa mengubah data', () {
    late String asli;
    setUp(() async {
      asli = await svc.exportZipTo(p.join(dir.path, 'asli.zip'));
    });

    Future<void> ditolak(String file, Matcher pesan) async {
      final sebelum = await keadaan();
      final foto = isiFoto();
      final berkas = semuaFile();
      await expectLater(svc.inspect(file), throwsA(isA<BackupInvalidException>().having((e) => e.pesan, 'pesan', pesan)));
      await expectLater(svc.restoreFrom(file), throwsA(isA<BackupInvalidException>().having((e) => e.pesan, 'pesan', pesan)));
      expect(await keadaan(), sebelum);
      expect(isiFoto(), foto);
      expect(semuaFile(), berkas); // tanpa cadangan otomatis, sisa file, atau file di luar folder
    }

    /// Zip baru dari [asli]: entri diganti/ditambah/dibuang, nama mentah apa adanya.
    String ubah(String nama, {Map<String, List<int>> ganti = const {}, Set<String> buang = const {}}) {
      final lama = ZipDecoder().decodeBytes(File(asli).readAsBytesSync());
      final baru = Archive();
      for (final f in lama.files) {
        if (buang.contains(f.name) || ganti.containsKey(f.name)) continue;
        baru.addFile(ArchiveFile.bytes(f.name, f.content));
      }
      for (final e in ganti.entries) {
        baru.addFile(ArchiveFile.bytes(e.key, e.value));
      }
      final f = File(p.join(dir.path, 'lain', nama))..createSync(recursive: true);
      f.writeAsBytesSync(ZipEncoder().encodeBytes(baru));
      return f.path;
    }

    List<int> manifest(Map<String, Object?> ubahan) {
      final m = jsonDecode(utf8.decode(ZipDecoder().decodeBytes(File(asli).readAsBytesSync())
          .findFile('manifest.json')!
          .content)) as Map<String, Object?>;
      return utf8.encode(jsonEncode({...m, ...ubahan}));
    }

    test('zip rusak: terpotong, isi tertimpa (CRC), kosong', () async {
      final bytes = File(asli).readAsBytesSync();
      final potong = File(p.join(dir.path, 'lain', 'potong.zip'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
      await ditolak(potong.path, contains('rusak'));

      // Timpa sebagian isi DB (entri pertama) tanpa mengubah direktori zip.
      final rusak = Uint8List.fromList(bytes);
      for (var i = 200; i < 1200; i++) {
        rusak[i] ^= 0x5A;
      }
      final f = File(p.join(dir.path, 'lain', 'rusak.zip'))..writeAsBytesSync(rusak);
      await ditolak(f.path, contains('rusak'));

      final kosong = File(p.join(dir.path, 'lain', 'kosong.zip'))..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04]);
      await ditolak(kosong.path, contains('rusak'));
    });

    test('manifest tidak dikenal / tidak ada / jumlah foto tidak cocok', () async {
      await ditolak(ubah('format.zip', ganti: {'manifest.json': manifest({'format': 'aplikasi-lain'})}),
          contains('Manifest cadangan tidak dikenal'));
      await ditolak(ubah('versi.zip', ganti: {'manifest.json': manifest({'versiFormat': 99})}),
          contains('Manifest cadangan tidak dikenal'));
      await ditolak(ubah('bukanjson.zip', ganti: {'manifest.json': utf8.encode('{bukan json')}),
          contains('Manifest cadangan tidak dikenal'));
      await ditolak(ubah('tanpa.zip', buang: {'manifest.json'}), contains('Manifest cadangan tidak ada'));
      await ditolak(
          ubah('jumlah.zip', ganti: {
            'manifest.json': manifest({
              'jumlahFoto': {'aset': 5, 'inventaris': 2}
            })
          }),
          contains('jumlah foto'));
      await ditolak(ubah('skema.zip', ganti: {'manifest.json': manifest({'versiSkema': 1})}), contains('versi skema'));
    });

    test('jalur berbahaya ("../", absolut, garis miring terbalik) dan file tak dikenal', () async {
      for (final (nama, jalur) in [
        ('naik.zip', '../evil.jpg'),
        ('naik2.zip', 'foto_aset/../../evil.jpg'),
        ('naik3.zip', 'foto_inventaris/../../../evil.jpg'),
        ('absolut.zip', '/tmp/evil.jpg'),
        ('windows.zip', r'foto_aset\..\..\evil.jpg'),
        ('drive.zip', 'C:/evil.jpg'),
      ]) {
        final f = ubah(nama, ganti: {jalur: [1, 2, 3]});
        // Nama mentah benar-benar ada di zip (encoder tidak membersihkannya).
        expect(ZipDecoder().decodeBytes(File(f).readAsBytesSync()).files.map((e) => e.name), contains(jalur));
        await ditolak(f, contains('jalur file berbahaya'));
      }
      expect(dir.parent.listSync().where((e) => p.basename(e.path) == 'evil.jpg'), isEmpty);
      await ditolak(ubah('asing.zip', ganti: {'virus.exe': [0]}), contains('tidak dikenal'));
      await ditolak(ubah('asing2.zip', ganti: {'foto_aset/aset_x.jpg': [0]}), contains('tidak dikenal'));
    });

    test('DB di dalam zip rusak atau hilang', () async {
      await ditolak(ubah('tanpadb.zip', buang: {'sikaya.db'}), contains('database tidak ada'));
      await ditolak(ubah('dbacak.zip', ganti: {'sikaya.db': List.generate(4096, (i) => i % 256)}),
          contains('bukan database SQLite'));
    });
  });
}
