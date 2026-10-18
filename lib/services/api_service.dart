import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/don_hang_model.dart';

class AdminSessionChangedException implements Exception {
  const AdminSessionChangedException();
  @override
  String toString() => 'Phiên đã thay đổi. Vui lòng thử lại.';
}

class ApiService {
  static http.Client _transport = http.Client();
  static http.Client get client => _SessionClient(_transport);
  static set client(http.Client value) {
    _transport = value is _SessionClient ? value.inner : value;
  }

  static int _sessionRevision = 0, _loginAttempt = 0;
  static int get sessionRevision => _sessionRevision;
  static Future<void> _storageQueue = Future.value();

  static Future<void> _persist(
    int revision,
    Future<void> Function(SharedPreferences) action,
  ) {
    final operation = _storageQueue.then((_) async {
      if (revision != _sessionRevision) return;
      final prefs = await SharedPreferences.getInstance();
      if (revision == _sessionRevision) await action(prefs);
    });
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  static void _installToken(String? token) {
    _sessionRevision++;
    _expiry?.cancel();
    _token = token;
  }

  static Timer? _expiry;
  static bool _watch(String? token) {
    _expiry?.cancel();
    try {
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token!.split('.')[1])),
                ),
              )
              as Map;
      final end = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
        isUtc: true,
      );
      if (!end.isAfter(DateTime.now().toUtc())) return false;
      final revision = _sessionRevision;
      _expiry = Timer(end.difference(DateTime.now().toUtc()), () {
        if (revision == _sessionRevision) unawaited(logout());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _serverUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5031',
  );
  static final String baseUrl = _apiBaseUrl(_serverUrl);
  static final authenticated = ValueNotifier<bool>(false);

  static String? _token;

  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "ngrok-skip-browser-warning": "true",
    if (_token != null) "Authorization": "Bearer $_token",
  };

  static void setToken(String token) {
    _installToken(token);
    _watch(token);
  }

  static Future<void> loadToken() async {
    final revision = _sessionRevision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _sessionRevision) return;
    _installToken(prefs.getString('jwt_token'));
    authenticated.value =
        (_token?.trim().isNotEmpty ?? false) &&
        prefs.getString('admin_role') == 'ADMIN' &&
        _watch(_token);
    if (!authenticated.value) await logout();
  }

  static Future<void> logout() async {
    _installToken(null);
    final revision = _sessionRevision;
    authenticated.value = false;
    await _persist(revision, (prefs) async {
      await prefs.remove('jwt_token');
      await prefs.remove('admin_ma_tk');
      await prefs.remove('admin_ten_dang_nhap');
      await prefs.remove('admin_role');
    });
  }

  static Future<Object?> getJson(String path) async {
    final response = await client
        .get(Uri.parse(baseUrl + path), headers: _headers)
        .timeout(const Duration(seconds: 20));
    _ensureJson(response);
    return response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<Object?> putJson(String path, Object data) async {
    final response = await client
        .put(
          Uri.parse(baseUrl + path),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
    _ensureJson(response);
    return response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  static void _ensureJson(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        throw Exception(data['message']);
      }
    } on FormatException {
      // Use the HTTP status when an error body is not JSON.
    }
    throw Exception('Không thể xử lý yêu cầu (HTTP ${response.statusCode})');
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final attempt = ++_loginAttempt;
    final startingRevision = _sessionRevision;
    final response = await client
        .post(
          Uri.parse('$baseUrl/identity/login'),
          headers: {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "true",
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (attempt != _loginAttempt || startingRevision != _sessionRevision) {
      throw const AdminSessionChangedException();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['accessToken'] is! String ||
          (data['accessToken'] as String).trim().isEmpty) {
        throw const FormatException(
          'Máy chủ không trả về phiên đăng nhập hợp lệ.',
        );
      }
      setToken(data['accessToken'] as String);
      final revision = _sessionRevision;

      final token = _token!;
      await _persist(revision, (prefs) async {
        await prefs.setString('jwt_token', token);
      });
      if (revision != _sessionRevision) {
        throw const AdminSessionChangedException();
      }

      return data;
    }

    if (response.body.contains('ERR_NGROK_3200')) {
      throw Exception(
        'Máy chủ đang ngoại tuyến. Vui lòng khởi động backend và cập nhật API_BASE_URL.',
      );
    }
    throw Exception(
      'Đăng nhập thất bại. Vui lòng kiểm tra lại Email/Mật khẩu.',
    );
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await client
        .get(Uri.parse('$baseUrl/identity/me'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Không thể lấy thông tin user (${response.statusCode})');
  }

  static Future<List<dynamic>> getDonHangChoNhan() async {
    final response = await client.get(
      Uri.parse('$baseUrl/order?status=PENDING'),
      headers: _headers,
    );
    return _handleOrderListResponse(response);
  }

  static Future<List<dynamic>> getDonHangDangHoatDong() async {
    final response = await client.get(
      Uri.parse('$baseUrl/order?status=ACTIVE'),
      headers: _headers,
    );
    return _handleOrderListResponse(response);
  }

  static Future<List<dynamic>> getDonHangQuanLy() async {
    final response = await client.get(
      Uri.parse('$baseUrl/order'),
      headers: _headers,
    );
    return _handleOrderListResponse(response);
  }

  static Future<int> getSoLuongDangGiao() async {
    final response = await client.get(
      Uri.parse('$baseUrl/order/count?status=DELIVERING'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final count = int.tryParse(response.body.trim());
    if (count == null || count < 0) {
      throw const FormatException('Số lượng đơn đang giao không hợp lệ.');
    }
    return count;
  }

  static Future<bool> phanDon(String maDon, String shipperId) async {
    final url = Uri.parse('$baseUrl/delivery/assign');
    final payload = <String, dynamic>{
      'orderId': maDon.trim(),
      'shipperId': shipperId.trim(),
    };

    try {
      final response = await client.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return true;
      throw Exception('Chỉ định Shipper thất bại: ${response.body}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi gọi API: $e');
    }
  }

  static Future<List<dynamic>> getDonHangByKhachHang(String maKh) async {
    final response = await client.get(
      Uri.parse('$baseUrl/order?customerId=$maKh'),
      headers: _headers,
    );
    return _handleOrderListResponse(response);
  }

  static Future<List<dynamic>> getDonHangByShipper(String maSp) async {
    final response = await client.get(
      Uri.parse('$baseUrl/order?shipperId=$maSp'),
      headers: _headers,
    );
    return _handleOrderListResponse(response);
  }

  static Future<Map<String, dynamic>> getChiTietDonHang(String maDh) async {
    final response = await client.get(
      Uri.parse('$baseUrl/order/$maDh'),
      headers: _headers,
    );
    final data = _handleMapResponse(response);
    data['trangThai'] = adminOrderStatus((data['trangThai'] ?? '').toString());
    return data;
  }

  static Future<bool> taoDonMoi(Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/order'),
      headers: _headers,
      body: json.encode(data),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> adminTaoDon(
    Map<String, dynamic> data,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/order'),
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Tạo đơn thất bại (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> adminCapNhatDon(
    String maDh,
    Map<String, dynamic> data,
  ) async {
    final response = await client.put(
      Uri.parse('$baseUrl/order/$maDh'),
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return {};
    throw Exception('Cập nhật đơn thất bại (${response.statusCode})');
  }

  static Future<void> adminXoaDon(String maDh) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/order/$maDh'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Xóa đơn thất bại (${response.statusCode})');
    }
  }

  static Future<bool> capNhatTrangThaiDonHang(Map<String, dynamic> data) async {
    final maDh = data['maDh'] ?? data['orderId'];
    final rawStatus = (data['trangThai'] ?? data['status']).toString();
    final status =
        const {
          'ChoXacNhan': 'PENDING',
          'ChoShipperXacNhan': 'ASSIGNED',
          'DaXacNhan': 'ACCEPTED',
          'DangGiao': 'DELIVERING',
          'DaGiao': 'COMPLETED',
          'DaHuy': 'CANCELLED',
          'GiaoThatBai': 'FAILED',
        }[rawStatus] ??
        rawStatus;
    final response = await client.patch(
      Uri.parse('$baseUrl/order/$maDh/status'),
      headers: _headers,
      body: json.encode(status),
    );
    return response.statusCode == 200;
  }

  static Future<bool> uploadMinhChung(Map<String, dynamic> data) async {
    final maDh = data['maDh'] ?? data['orderId'];
    final response = await client.post(
      Uri.parse('$baseUrl/delivery/$maDh/complete'),
      headers: _headers,
      body: jsonEncode({
        'imageUrl': data['imageUrl'] ?? data['hinhAnh'],
        'otpSignature': data['otpSignature'] ?? data['chuKyOtp'],
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> baoGiaoThatBai(Map<String, dynamic> data) async {
    data['status'] = 'FAILED';
    return await capNhatTrangThaiDonHang(data);
  }

  static Future<List<dynamic>> getShipperChoDuyet() async {
    final response = await client.get(
      Uri.parse('$baseUrl/identity/shippers?status=PENDING'),
      headers: _headers,
    );
    return _handleListResponse(response);
  }

  static Future<List<dynamic>> getDanhSachShipper() async {
    final response = await client.get(
      Uri.parse('$baseUrl/identity/shippers'),
      headers: _headers,
    );
    return _handleListResponse(response);
  }

  static Future<bool> doiTrangThaiHoatDongShipper(
    Map<String, dynamic> data,
  ) async {
    final maShipper = data['maShipper'];
    final response = await client.patch(
      Uri.parse('$baseUrl/identity/shippers/$maShipper/status'),
      headers: _headers,
      body: json.encode({'status': data['trangThaiMoi']}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> forceOffline(String maShipper) async {
    return await doiTrangThaiHoatDongShipper({
      'maShipper': maShipper,
      'trangThaiMoi': 'OFFLINE',
    });
  }

  static Future<Map<String, dynamic>> getChiTietShipper(
    String shipperId,
  ) async {
    final response = await client.get(
      Uri.parse('$baseUrl/identity/users/$shipperId'),
      headers: _headers,
    );
    return _handleMapResponse(response);
  }

  static Future<void> duyetHoSoShipper({
    required String maShipper,
    required bool isApproved,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/identity/shippers/$maShipper/approve'),
      headers: _headers,
      body: jsonEncode({'isApproved': isApproved}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Thao tác phê duyệt thất bại');
    }
  }

  static Future<bool> capNhatGpsShipper(Map<String, dynamic> data) async {
    final response = await client.put(
      Uri.parse('$baseUrl/identity/me/location'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _ensureSuccess(response);
    return true;
  }

  static Future<Map<String, dynamic>> getViCodShipper(String maShipper) async {
    final response = await client.get(
      Uri.parse('$baseUrl/finance/wallet/$maShipper'),
      headers: _headers,
    );
    return _handleMapResponse(response);
  }

  static Future<Map<String, dynamic>> getBangLuongShipper(
    String maShipper,
  ) async {
    final response = await client.get(
      Uri.parse('$baseUrl/finance/salary/$maShipper'),
      headers: _headers,
    );
    return _handleMapResponse(response);
  }

  static Future<int> getSoLuongCanhBaoCod() async {
    final response = await client.get(
      Uri.parse('$baseUrl/finance/warnings/count'),
      headers: _headers,
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as num).toInt();
  }

  static Future<List<dynamic>> getDanhSachPhieuChoDuyet() async {
    final response = await client.get(
      Uri.parse('$baseUrl/finance/reconciliations?status=ChoDuyet'),
      headers: _headers,
    );
    return _handleListResponse(response);
  }

  static Future<bool> taoPhieuDoiSoat(Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/finance/reconciliations'),
      headers: _headers,
      body: jsonEncode({
        'shipperId': data['shipperId'] ?? data['maSp'],
        'amount': data['amount'] ?? data['tongTienNop'],
      }),
    );
    _ensureSuccess(response);
    return true;
  }

  static Future<bool> duyetPhieuDoiSoat(Map<String, dynamic> data) async {
    final id = data['maDs'];
    final response = await client.post(
      Uri.parse('$baseUrl/finance/reconciliations/$id/approve'),
      headers: _headers,
    );
    _ensureSuccess(response);
    return true;
  }

  static Future<dynamic> getGioCaoDiem() async {
    final response = await client.get(
      Uri.parse('$baseUrl/systemconfig/peak-hours'),
      headers: _headers,
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Lỗi lấy thông tin giờ cao điểm');
  }

  static Future<bool> updateGioCaoDiem(Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse('$baseUrl/systemconfig/peak-hours'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _ensureSuccess(response);
    return true;
  }

  static Future<dynamic> getThamSoHeThong() async {
    final response = await client.get(
      Uri.parse('$baseUrl/systemconfig/parameters'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) return decoded['data'];
    throw const FormatException('Phản hồi tham số hệ thống không hợp lệ.');
  }

  static Future<bool> updateThamSoHeThong({
    required String maThamSo,
    required String giaTri,
    String? moTa,
  }) async {
    final response = await client.put(
      Uri.parse('$baseUrl/systemconfig/parameters/$maThamSo'),
      headers: _headers,
      body: jsonEncode({'giaTri': giaTri, 'moTa': moTa}),
    );
    _ensureSuccess(response);
    return true;
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Lỗi API (${response.statusCode}): ${response.body}');
    }
  }

  static Future<ShippingRouteData> getShippingRoute({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    String? customerId,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/delivery/quote'),
      headers: _headers,
      body: jsonEncode({
        'viDoLay': pickupLat,
        'kinhDoLay': pickupLng,
        'viDoGiao': deliveryLat,
        'kinhDoGiao': deliveryLng,
        if (customerId != null && customerId.isNotEmpty)
          'customerId': customerId,
      }),
    );
    _ensureSuccess(response);
    return ShippingRouteData.fromJson(jsonDecode(response.body));
  }

  static List<dynamic> _handleOrderListResponse(http.Response response) =>
      _handleListResponse(response).map((item) {
        if (item is! Map) return item;
        final data = Map<String, dynamic>.from(item);
        data['trangThai'] = adminOrderStatus(
          (data['trangThai'] ?? data['TrangThai'] ?? '').toString(),
        );
        return data;
      }).toList();
  static List<dynamic> _handleListResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        return decoded['data'] as List<dynamic>;
      }
      return [];
    }
    throw Exception('Lỗi API (${response.statusCode}): ${response.body}');
  }

  static Map<String, dynamic> _handleMapResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    }
    throw Exception('Lỗi API (${response.statusCode}): ${response.body}');
  }
}

String _apiBaseUrl(String value) {
  final root = value.trim().replaceAll(RegExp(r'/+$'), '');
  return root.endsWith('/api') ? root : '$root/api';
}

class ShippingRoutePoint {
  const ShippingRoutePoint({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

class ShippingRouteData {
  const ShippingRouteData({
    required this.distanceKm,
    required this.durationMinutes,
    required this.shippingFee,
    required this.routePoints,
  });

  final double distanceKm;
  final int durationMinutes;
  final double shippingFee;
  final List<ShippingRoutePoint> routePoints;

  factory ShippingRouteData.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value');
    final distance = number(json['distanceKm']);
    final fee = number(json['shippingFee']);
    final duration = number(json['durationMinutes']);
    if (distance == null ||
        !distance.isFinite ||
        distance <= 0 ||
        fee == null ||
        !fee.isFinite ||
        fee < 0 ||
        duration == null ||
        !duration.isFinite ||
        duration < 0) {
      throw const FormatException('Báo giá vận chuyển không hợp lệ.');
    }
    final points = <ShippingRoutePoint>[];
    if (json['routePoints'] is List) {
      for (final item in json['routePoints'] as List) {
        if (item is! Map) continue;
        final lat = number(item['latitude']), lng = number(item['longitude']);
        if (lat != null &&
            lng != null &&
            lat.isFinite &&
            lng.isFinite &&
            lat.abs() <= 90 &&
            lng.abs() <= 180) {
          points.add(ShippingRoutePoint(latitude: lat, longitude: lng));
        }
      }
    }
    return ShippingRouteData(
      distanceKm: distance,
      durationMinutes: duration.round(),
      shippingFee: fee,
      routePoints: points,
    );
  }
}

class ShipperPickupRouteData {
  const ShipperPickupRouteData({
    required this.distanceKm,
    required this.durationMinutes,
  });
  final double distanceKm;
  final double durationMinutes;
}

class OsrmService {
  static Future<ShipperPickupRouteData?> getShipperToPickupRoute({
    required double shipperLat,
    required double shipperLng,
    required double pickupLat,
    required double pickupLng,
  }) async {
    final String url =
        'https://router.project-osrm.org/route/v1/driving/$shipperLng,$shipperLat;$pickupLng,$pickupLat?overview=false&steps=false';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'LogiRoute-Admin-App/1.0'},
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map ||
          data['routes'] is! List ||
          (data['routes'] as List).isEmpty) {
        return null;
      }
      final route = Map<String, dynamic>.from(
        (data['routes'] as List).first as Map,
      );
      final distanceMeters = (route['distance'] as num?)?.toDouble();
      final durationSeconds = (route['duration'] as num?)?.toDouble();
      if (distanceMeters == null || durationSeconds == null) return null;
      return ShipperPickupRouteData(
        distanceKm: double.parse((distanceMeters / 1000).toStringAsFixed(1)),
        durationMinutes: double.parse(
          (durationSeconds / 60).toStringAsFixed(1),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, double>> getRealRouting(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final String url =
        'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=false';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          return {
            'distance': double.parse(
              (route['distance'] / 1000.0).toStringAsFixed(1),
            ),
            'duration': double.parse(
              (route['duration'] / 60.0).toStringAsFixed(1),
            ),
          };
        }
      }
    } catch (e) {
      debugPrint('Lỗi OSRM: $e');
    }
    throw Exception(
      'Không thể xác định tuyến đường. Vui lòng thử lại trước khi tính phí.',
    );
  }
}

class _SessionClient extends http.BaseClient {
  _SessionClient(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final revision = ApiService._sessionRevision;
    final sent = request.headers['Authorization'];
    if (sent != null && sent != 'Bearer ${ApiService._token ?? ''}') {
      throw const AdminSessionChangedException();
    }
    late final http.StreamedResponse response;
    try {
      response = await _read(request).timeout(const Duration(seconds: 20));
    } catch (_) {
      if (revision != ApiService._sessionRevision) {
        throw const AdminSessionChangedException();
      }
      rethrow;
    }
    if (revision != ApiService._sessionRevision) {
      throw const AdminSessionChangedException();
    }
    if (response.statusCode == 401 && sent != null) {
      await ApiService.logout();
    }
    return response;
  }

  Future<http.StreamedResponse> _read(http.BaseRequest request) async {
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      contentLength: bytes.length,
      request: response.request ?? request,
      reasonPhrase: response.reasonPhrase,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
    );
  }
}
