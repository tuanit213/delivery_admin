double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

class CauHinhGioCaoDiemModel {
  final String maCd;
  final String gioBatDau;
  final String gioKetThuc;
  final double heSoPhi;
  final String? moTa;

  CauHinhGioCaoDiemModel({
    required this.maCd,
    required this.gioBatDau,
    required this.gioKetThuc,
    required this.heSoPhi,
    this.moTa,
  });

  factory CauHinhGioCaoDiemModel.fromJson(Map<String, dynamic> json) {
    return CauHinhGioCaoDiemModel(
      maCd: (json['maCd'] ?? json['MaCd'] ?? 'CD01').toString(),
      gioBatDau: (json['gioBatDau'] ?? json['GioBatDau'] ?? '07:30:00')
          .toString(),
      gioKetThuc: (json['gioKetThuc'] ?? json['GioKetThuc'] ?? '19:00:00')
          .toString(),
      heSoPhi: _parseDouble(
        json['heSoPhi'] ?? json['HeSoPhi'] ?? json['heSoPhuPhi'],
        1.5,
      ),
      moTa: json['moTa'] ?? json['MoTa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maCd': maCd,
      'gioBatDau': gioBatDau,
      'gioKetThuc': gioKetThuc,
      'heSoPhi': heSoPhi,
      'moTa': moTa ?? 'Khung giờ cao điểm áp dụng phụ phí',
    };
  }

  CauHinhGioCaoDiemModel copyWith({
    String? maCd,
    String? gioBatDau,
    String? gioKetThuc,
    double? heSoPhi,
    String? moTa,
  }) {
    return CauHinhGioCaoDiemModel(
      maCd: maCd ?? this.maCd,
      gioBatDau: gioBatDau ?? this.gioBatDau,
      gioKetThuc: gioKetThuc ?? this.gioKetThuc,
      heSoPhi: heSoPhi ?? this.heSoPhi,
      moTa: moTa ?? this.moTa,
    );
  }
}
