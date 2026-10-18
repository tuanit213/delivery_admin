import 'dart:convert';
import 'package:admin/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout clears token, admin identity and authenticated state', () async {
    SharedPreferences.setMockInitialValues({
      'jwt_token':
          'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature',
      'admin_ma_tk': 'admin-1',
      'admin_ten_dang_nhap': 'admin@example.com',
      'admin_role': 'ADMIN',
      'remember_me': true,
      'saved_username': 'admin@example.com',
    });
    await ApiService.loadToken();
    expect(ApiService.authenticated.value, isTrue);
    await ApiService.logout();
    expect(ApiService.authenticated.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'jwt_token',
      'admin_ma_tk',
      'admin_ten_dang_nhap',
      'admin_role',
    ]) {
      expect(prefs.containsKey(key), isFalse);
    }
    expect(prefs.getString('saved_username'), 'admin@example.com');
  });

  test('a stored non-admin token does not unlock admin routes', () async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test-token',
      'admin_role': 'CUSTOMER',
    });
    await ApiService.loadToken();
    expect(ApiService.authenticated.value, isFalse);
  });

  test('writes call the backend and propagate failures', () async {
    final originalClient = ApiService.client;
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response('{"message":"Validation failed"}', 400);
    });
    ApiService.client = mock;
    addTearDown(() {
      ApiService.client = originalClient;
      mock.close();
    });
    for (final action in <Future<bool> Function()>[
      () => ApiService.duyetPhieuDoiSoat({'maDs': 'test-id'}),
      () =>
          ApiService.taoPhieuDoiSoat({'maSp': 'driver-id', 'tongTienNop': 100}),
      () => ApiService.updateGioCaoDiem({}),
      () => ApiService.updateThamSoHeThong(maThamSo: 'test', giaTri: '1'),
      () => ApiService.capNhatGpsShipper({}),
    ]) {
      await expectLater(action(), throwsException);
    }
    expect(requests.length, 5);
    expect(
      requests[0].url.path,
      '/api/finance/reconciliations/test-id/approve',
    );
    expect(requests[2].url.path, '/api/systemconfig/peak-hours');
    expect(requests[4].method, 'PUT');
    expect(requests[4].url.path, '/api/identity/me/location');
  });

  test(
    'order lists normalize canonical server statuses for admin filters',
    () async {
      final originalClient = ApiService.client;
      final mock = MockClient(
        (request) async =>
            http.Response('[{"maDh":"order-1","trangThai":"COMPLETED"}]', 200),
      );
      ApiService.client = mock;
      addTearDown(() {
        ApiService.client = originalClient;
        mock.close();
      });
      final orders = await ApiService.getDonHangQuanLy();
      expect(orders.single['trangThai'], 'DaGiao');
    },
  );
}
