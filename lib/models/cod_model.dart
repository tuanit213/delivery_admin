double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? defaultValue;
  return defaultValue;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

class CodModel {
  const CodModel({
    required this.maDs,
    required this.maSp,
    required this.tongTienNop,
    required this.trangThai,
    this.nguoiDuyet,
    this.ngayDoiSoat,
  });

  final String maDs;
  final String maSp;
  final String? nguoiDuyet;
  final DateTime? ngayDoiSoat;
  final double tongTienNop;
  final String trangThai;

  bool get isPending {
    final value = trangThai.trim().toUpperCase().replaceAll('_', '');
    return value == 'CHODUYET';
  }

  bool get isApproved {
    final value = trangThai.trim().toUpperCase().replaceAll('_', '');
    return value == 'DADUYET';
  }

  factory CodModel.fromJson(Map<String, dynamic> json) {
    return CodModel(
      maDs: (json['maDs'] ?? json['MaDs'] ?? '').toString(),
      maSp: (json['maSp'] ?? json['MaSp'] ?? '').toString(),
      nguoiDuyet: (json['nguoiDuyet'] ?? json['NguoiDuyet'])?.toString(),
      ngayDoiSoat: _parseDateTime(json['ngayDoiSoat'] ?? json['NgayDoiSoat']),
      tongTienNop: _parseDouble(json['tongTienNop'] ?? json['TongTienNop']),
      trangThai: (json['trangThai'] ?? json['TrangThai'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'maDs': maDs,
    'maSp': maSp,
    'nguoiDuyet': nguoiDuyet,
    'ngayDoiSoat': ngayDoiSoat?.toIso8601String(),
    'tongTienNop': tongTienNop,
    'trangThai': trangThai,
  };
}
