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

String? _parseNullableString(dynamic value) {
  if (value == null) return null;

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
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
        lowerValue == '1' ||
        lowerValue == 'gap' ||
        lowerValue == 'urgent';
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

class DonHangModel {
  final String id;
  final String maDon;
  final String thoiGianCho;
  final double trongLuong;
  final String kichThuoc;
  final double dungTich;
  final String tinhChat;

  final String diemLayHang;
  final String lienHeLayHang;

  final String diemGiaoHang;
  final String lienHeGiaoHang;

  final String tenNguoiNhan;

  final String? maShipper;

  final String trangThai;
  final DateTime? ngayTao;

  final int duKienGiaoPhut;
  final String giaCuoc;
  final String hinhThucGiao;
  final String tienCod;
  final double quangDuongKm;
  final bool isUrgent;

  /// vì vậy bắt buộc phải để nullable.
  final double? pickupLatitude;
  final double? pickupLongitude;

  final double? deliveryLatitude;
  final double? deliveryLongitude;

  const DonHangModel({
    required this.id,
    required this.maDon,
    required this.thoiGianCho,
    required this.trongLuong,
    required this.kichThuoc,
    required this.dungTich,
    required this.tinhChat,
    required this.diemLayHang,
    required this.lienHeLayHang,
    required this.diemGiaoHang,
    required this.lienHeGiaoHang,
    required this.tenNguoiNhan,
    required this.maShipper,
    required this.trangThai,
    required this.ngayTao,
    required this.duKienGiaoPhut,
    required this.giaCuoc,
    required this.hinhThucGiao,
    required this.tienCod,
    required this.quangDuongKm,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.isUrgent = false,
  });

  bool get hasValidPickupLocation {
    final lat = pickupLatitude;
    final lng = pickupLongitude;

    if (lat == null || lng == null) {
      return false;
    }

    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  bool get hasValidDeliveryLocation {
    final lat = deliveryLatitude;
    final lng = deliveryLongitude;

    if (lat == null || lng == null) {
      return false;
    }

    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  bool get hasCompleteLocation {
    return hasValidPickupLocation && hasValidDeliveryLocation;
  }

  factory DonHangModel.fromJson(Map<String, dynamic> json) {
    return DonHangModel(
      id: (json['maDh'] ?? json['MaDh'] ?? json['id'] ?? json['Id'] ?? '')
          .toString(),

      maDon:
          (json['maDh'] ??
                  json['MaDh'] ??
                  json['maDon'] ??
                  json['MaDon'] ??
                  '#ORD-UNKNOWN')
              .toString(),

      thoiGianCho: (json['thoiGianCho'] ?? json['ThoiGianCho'] ?? '00:00')
          .toString(),

      trongLuong: _parseDouble(
        json['khoiLuong'] ??
            json['KhoiLuong'] ??
            json['trongLuong'] ??
            json['TrongLuong'],
      ),

      kichThuoc: (json['kichThuoc'] ?? json['KichThuoc'] ?? 'N/A').toString(),

      dungTich: _parseDouble(json['dungTich'] ?? json['DungTich']),

      tinhChat: (json['tinhChat'] ?? json['TinhChat'] ?? 'THƯỜNG').toString(),

      diemLayHang:
          (json['diaChiLay'] ??
                  json['DiaChiLay'] ??
                  json['diemLayHang'] ??
                  json['DiemLayHang'] ??
                  '')
              .toString(),

      lienHeLayHang:
          (json['sdtNguoiGui'] ??
                  json['SdtNguoiGui'] ??
                  json['lienHeLayHang'] ??
                  json['LienHeLayHang'] ??
                  '')
              .toString(),

      diemGiaoHang:
          (json['diaChiGiao'] ??
                  json['DiaChiGiao'] ??
                  json['diemGiaoHang'] ??
                  json['DiemGiaoHang'] ??
                  '')
              .toString(),

      lienHeGiaoHang:
          (json['sdtNguoiNhan'] ??
                  json['SdtNguoiNhan'] ??
                  json['lienHeGiaoHang'] ??
                  json['LienHeGiaoHang'] ??
                  '')
              .toString(),

      tenNguoiNhan: (json['tenNguoiNhan'] ?? json['TenNguoiNhan'] ?? '')
          .toString(),

      maShipper: _parseNullableString(
        json['maSp'] ?? json['MaSp'] ?? json['maShipper'] ?? json['MaShipper'],
      ),

      trangThai: adminOrderStatus(
        (json['trangThai'] ?? json['TrangThai'] ?? '').toString(),
      ),

      ngayTao: _parseDateTime(json['ngayTao'] ?? json['NgayTao']),

      duKienGiaoPhut: _parseInt(
        json['duKienGiaoPhut'] ?? json['DuKienGiaoPhut'],
      ),

      giaCuoc:
          (json['phiGiaoHang'] ??
                  json['PhiGiaoHang'] ??
                  json['giaCuoc'] ??
                  json['GiaCuoc'] ??
                  0)
              .toString(),

      hinhThucGiao:
          (json['hinhThucGiao'] ?? json['HinhThucGiao'] ?? 'Tiêu chuẩn')
              .toString(),

      tienCod: (json['tienCod'] ?? json['TienCod'] ?? 0).toString(),

      quangDuongKm: _parseDouble(
        json['khoangCach'] ??
            json['KhoangCach'] ??
            json['quangDuongKm'] ??
            json['QuangDuongKm'] ??
            json['distanceKm'],
      ),

      isUrgent: _parseBool(json['isUrgent'] ?? json['IsUrgent']),

      pickupLatitude: _parseNullableDouble(
        json['pickupLatitude'] ??
            json['PickupLatitude'] ??
            json['viDoLay'] ??
            json['ViDoLay'] ??
            json['latLay'] ??
            json['LatLay'],
      ),

      pickupLongitude: _parseNullableDouble(
        json['pickupLongitude'] ??
            json['PickupLongitude'] ??
            json['kinhDoLay'] ??
            json['KinhDoLay'] ??
            json['lngLay'] ??
            json['LngLay'],
      ),

      deliveryLatitude: _parseNullableDouble(
        json['deliveryLatitude'] ??
            json['DeliveryLatitude'] ??
            json['viDoGiao'] ??
            json['ViDoGiao'] ??
            json['latGiao'] ??
            json['LatGiao'],
      ),

      deliveryLongitude: _parseNullableDouble(
        json['deliveryLongitude'] ??
            json['DeliveryLongitude'] ??
            json['kinhDoGiao'] ??
            json['KinhDoGiao'] ??
            json['lngGiao'] ??
            json['LngGiao'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'maDon': maDon,
      'thoiGianCho': thoiGianCho,
      'trongLuong': trongLuong,
      'kichThuoc': kichThuoc,
      'dungTich': dungTich,
      'tinhChat': tinhChat,
      'diemLayHang': diemLayHang,
      'lienHeLayHang': lienHeLayHang,
      'diemGiaoHang': diemGiaoHang,
      'lienHeGiaoHang': lienHeGiaoHang,
      'tenNguoiNhan': tenNguoiNhan,
      'maSp': maShipper,
      'trangThai': trangThai,
      'ngayTao': ngayTao?.toIso8601String(),
      'duKienGiaoPhut': duKienGiaoPhut,
      'giaCuoc': giaCuoc,
      'hinhThucGiao': hinhThucGiao,
      'tienCod': tienCod,
      'quangDuongKm': quangDuongKm,
      'isUrgent': isUrgent,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
    };
  }
}

String adminOrderStatus(String status) =>
    const {
      'PENDING': 'ChoXacNhan',
      'ASSIGNED': 'ChoShipperXacNhan',
      'ACCEPTED': 'DaXacNhan',
      'DELIVERING': 'DangGiao',
      'COMPLETED': 'DaGiao',
      'CANCELLED': 'DaHuy',
      'FAILED': 'GiaoThatBai',
      'RETURNED': 'DaHoanTra',
    }[status.toUpperCase()] ??
    status;

String adminOrderStatusLabel(String status) =>
    const {
      'ChoXacNhan': 'Chờ phân công',
      'ChoShipperXacNhan': 'Chờ tài xế xác nhận',
      'DaXacNhan': 'Tài xế đã nhận đơn',
      'DangGiao': 'Đang giao hàng',
      'DaGiao': 'Đã giao thành công',
      'DaHuy': 'Đã hủy',
      'GiaoThatBai': 'Giao hàng thất bại',
      'DaHoanTra': 'Đã hoàn trả',
    }[adminOrderStatus(status)] ??
    status;
