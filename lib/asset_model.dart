class AssetModel {
  final int? id;
  final String nama;
  final String kategori;
  final String deskripsi;
  final int jumlah;
  final String imagePath;
  final String date; 
  final String kondisi;
  
  final String? satuan;
  final String? expiredDate;
  final int? usageForTernak;
  final int? usageDuration;

  // [BARU] Kolom Tambahan untuk Aset Tetap
  final String? statusKepemilikan; // Hak Milik, Sewa, dll
  final String? fungsiLahan;       // Peternakan, Pertanian (Bisa lebih dari 1, dipisah koma)

  AssetModel({
    this.id,
    required this.nama,
    required this.kategori,
    required this.jumlah,
    required this.deskripsi,
    required this.imagePath,
    required this.date,
    required this.kondisi,
    this.satuan,
    this.expiredDate,
    this.usageForTernak,
    this.usageDuration,
    this.statusKepemilikan,
    this.fungsiLahan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': nama,
      'category': kategori,
      'description': deskripsi,
      'quantity': jumlah,
      'imagePath': imagePath,
      'date': date,
      'condition': kondisi,
      'unit': satuan,
      'expired_date': expiredDate,
      'usage_ternak': usageForTernak,
      'usage_days': usageDuration,
      // Simpan field baru
      'ownership_status': statusKepemilikan,
      'land_function': fungsiLahan,
    };
  }

  factory AssetModel.fromMap(Map<String, dynamic> map) {
    return AssetModel(
      id: map['id'],
      nama: map['name'],
      kategori: map['category'],
      deskripsi: map['description'],
      jumlah: map['quantity'],
      imagePath: map['imagePath'],
      date: map['date'],
      kondisi: map['condition'],
      satuan: map['unit'],
      expiredDate: map['expired_date'],
      usageForTernak: map['usage_ternak'],
      usageDuration: map['usage_days'],
      // Ambil field baru
      statusKepemilikan: map['ownership_status'],
      fungsiLahan: map['land_function'],
    );
  }
}