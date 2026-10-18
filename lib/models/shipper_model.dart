double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? defaultValue;
  }

  return defaultValue;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    return double.tryParse(trimmedValue);
  }

  return null;
}

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim()) ?? defaultValue;
  }

  return defaultValue;
}

bool _parseBool(dynamic value, [bool defaultValue = false]) {
  if (value == null) return defaultValue;

  if (value is bool) {
    return value;
  }

  if (value is String) {
    final lowerValue = value.trim().toLowerCase();

    return lowerValue == 'true' ||
        lowerValue == 'tructuyen' ||
        lowerValue == 'online' ||
        lowerValue == '1';
  }

  if (value is num) {
    return value == 1;
  }

  return defaultValue;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;

  final rawValue = value.toString().trim();

  if (rawValue.isEmpty) {
    return null;
  }

  return DateTime.tryParse(rawValue);
}

class ShipperModel {
  final String id;
  final String hoTen;
  final String bienSo;
  final String soDienThoai;
  final double danhGia;
  final int soDonDaGiao;
  final double khoangCachKm;
  final int thoiGianRanhPhut;

  final double taiTrongToiDa;
  final double taiTrongDangNhan;
  final double taiTrongConLai;
  final int soDonDangXuLy;
  final bool isOnline;
  final bool isOptimal;
  final String trangThaiDuyet;
  final String? lyDoKhongKhaDung;

  /// GPS phải nullable.

  final double? lat;
  final double? lng;

  final DateTime? locationUpdatedAt;

  final bool dangRanh;

  final DateTime? ranhTu;

  final DateTime? thoiGianBatDauOnline;

  final bool dangCoDonHoatDong;

  final DateTime? lanHoanThanhGanNhat;

  const ShipperModel({
    required this.id,
    required this.hoTen,
    required this.bienSo,
    required this.soDienThoai,
    required this.danhGia,
    required this.soDonDaGiao,
    required this.khoangCachKm,
    required this.thoiGianRanhPhut,
    required this.taiTrongToiDa,
    required this.taiTrongDangNhan,
    required this.taiTrongConLai,
    required this.soDonDangXuLy,
    required this.trangThaiDuyet,
    required this.lat,
    required this.lng,
    required this.locationUpdatedAt,
    required this.dangRanh,
    required this.ranhTu,
    required this.thoiGianBatDauOnline,
    required this.dangCoDonHoatDong,
    required this.lanHoanThanhGanNhat,
    this.isOnline = false,
    this.isOptimal = false,
    this.lyDoKhongKhaDung,
  });

  bool canAcceptWeight(double orderWeightKg) {
    if (!isOnline || orderWeightKg <= 0 || taiTrongToiDa <= 0) {
      return false;
    }

    return taiTrongDangNhan + orderWeightKg < taiTrongToiDa;
  }

  bool get hasValidLocation {
    final currentLat = lat;
    final currentLng = lng;

    if (currentLat == null || currentLng == null) {
      return false;
    }

    return currentLat >= -90 &&
        currentLat <= 90 &&
        currentLng >= -180 &&
        currentLng <= 180;
  }

  /// Có GPS nhưng dữ liệu đã quá 5 phút.

  bool get isLocationStale {
    final updatedAt = locationUpdatedAt;

    if (updatedAt == null) {
      return true;
    }

    final now = updatedAt.isUtc ? DateTime.now().toUtc() : DateTime.now();

    return now.difference(updatedAt).inMinutes > 5;
  }

  /// Không dùng `thoiGianRanhPhut` snapshot để chạy timer vì snapshot

  Duration get idleDurationNow {
    if (!dangRanh || ranhTu == null) {
      return Duration.zero;
    }

    final now = ranhTu!.isUtc ? DateTime.now().toUtc() : DateTime.now();
    final elapsed = now.difference(ranhTu!);

    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  factory ShipperModel.fromJson(Map<String, dynamic> json) {
    return ShipperModel(
      id:
          (json['maSp'] ??
                  json['MaSp'] ??
                  json['maTk'] ??
                  json['MaTk'] ??
                  json['id'] ??
                  json['Id'] ??
                  '')
              .toString(),

      hoTen: (json['hoTen'] ?? json['HoTen'] ?? 'Tài xế').toString(),

      bienSo:
          (json['bienSoXe'] ??
                  json['BienSoXe'] ??
                  json['bienSo'] ??
                  json['BienSo'] ??
                  'N/A')
              .toString(),

      soDienThoai: (json['soDienThoai'] ?? json['SoDienThoai'] ?? 'N/A')
          .toString(),

      danhGia: _parseDouble(json['danhGia'] ?? json['DanhGia'], 0.0),

      soDonDaGiao: _parseInt(json['soDonDaGiao'] ?? json['SoDonDaGiao']),

      khoangCachKm: _parseDouble(json['khoangCachKm'] ?? json['KhoangCachKm']),

      thoiGianRanhPhut: _parseInt(
        json['thoiGianRanhPhut'] ?? json['ThoiGianRanhPhut'],
      ),

      taiTrongToiDa: _parseDouble(
        json['taiTrongToiDa'] ?? json['TaiTrongToiDa'],
      ),

      taiTrongDangNhan: _parseDouble(
        json['taiTrongDangNhan'] ?? json['TaiTrongDangNhan'],
      ),

      taiTrongConLai: _parseDouble(
        json['taiTrongConLai'] ?? json['TaiTrongConLai'],
      ),

      soDonDangXuLy: _parseInt(json['soDonDangXuLy'] ?? json['SoDonDangXuLy']),

      isOnline: _parseBool(
        json['trangThaiHoatDong'] ??
            json['TrangThaiHoatDong'] ??
            json['isOnline'] ??
            json['IsOnline'],
        false,
      ),

      isOptimal: _parseBool(json['isOptimal'] ?? json['IsOptimal']),

      trangThaiDuyet:
          (json['trangThaiHoSo'] ??
                  json['TrangThaiHoSo'] ??
                  json['trangThaiDuyet'] ??
                  json['TrangThaiDuyet'] ??
                  'ChoDuyet')
              .toString(),

      lyDoKhongKhaDung: (json['lyDoKhongKhaDung'] ?? json['LyDoKhongKhaDung'])
          ?.toString(),

      lat: _parseNullableDouble(
        json['latitude'] ??
            json['Latitude'] ??
            json['viDo'] ??
            json['ViDo'] ??
            json['lat'] ??
            json['Lat'],
      ),

      lng: _parseNullableDouble(
        json['longitude'] ??
            json['Longitude'] ??
            json['kinhDo'] ??
            json['KinhDo'] ??
            json['lng'] ??
            json['Lng'],
      ),

      locationUpdatedAt: _parseDateTime(
        json['locationUpdatedAt'] ??
            json['LocationUpdatedAt'] ??
            json['thoiGianCapNhat'] ??
            json['ThoiGianCapNhat'],
      ),

      dangRanh: _parseBool(json['dangRanh'] ?? json['DangRanh'], false),

      ranhTu: _parseDateTime(json['ranhTu'] ?? json['RanhTu']),

      thoiGianBatDauOnline: _parseDateTime(
        json['thoiGianBatDauOnline'] ?? json['ThoiGianBatDauOnline'],
      ),

      dangCoDonHoatDong: _parseBool(
        json['dangCoDonHoatDong'] ?? json['DangCoDonHoatDong'],
        false,
      ),

      lanHoanThanhGanNhat: _parseDateTime(
        json['lanHoanThanhGanNhat'] ?? json['LanHoanThanhGanNhat'],
      ),
    );
  }

  bool get hasRealRating => danhGia > 0;

  bool get hasDeliveredOrders => soDonDaGiao > 0;

  Map<String, dynamic> toJson() {
    return {
      'maSp': id,
      'hoTen': hoTen,
      'bienSoXe': bienSo,
      'soDienThoai': soDienThoai,
      'danhGia': danhGia,
      'soDonDaGiao': soDonDaGiao,
      'khoangCachKm': khoangCachKm,
      'thoiGianRanhPhut': thoiGianRanhPhut,
      'trangThaiHoatDong': isOnline ? 'TrucTuyen' : 'NgoaiTuyen',
      'isOptimal': isOptimal,
      'trangThaiDuyet': trangThaiDuyet,
      'lyDoKhongKhaDung': lyDoKhongKhaDung,
      'latitude': lat,
      'longitude': lng,
      'locationUpdatedAt': locationUpdatedAt?.toIso8601String(),
      'taiTrongToiDa': taiTrongToiDa,
      'taiTrongDangNhan': taiTrongDangNhan,
      'taiTrongConLai': taiTrongConLai,
      'soDonDangXuLy': soDonDangXuLy,
      'dangRanh': dangRanh,
      'ranhTu': ranhTu?.toIso8601String(),
      'thoiGianBatDauOnline': thoiGianBatDauOnline?.toIso8601String(),
      'dangCoDonHoatDong': dangCoDonHoatDong,
      'lanHoanThanhGanNhat': lanHoanThanhGanNhat?.toIso8601String(),
    };
  }
}
