import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('malformed saved token cannot restore Admin access', () async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'invalid',
      'admin_role': 'ADMIN',
    });
    await ApiService.loadToken();
    expect(ApiService.authenticated.value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).containsKey('jwt_token'),
      isFalse,
    );
  });
  test('authenticated 401 clears admin identity immediately', () async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'old',
      'admin_role': 'ADMIN',
      'admin_ma_tk': 'a1',
    });
    final previous = ApiService.client;
    ApiService.client = MockClient((_) async => http.Response('', 401));
    addTearDown(() {
      ApiService.client = previous;
    });
    ApiService.setToken('old');
    ApiService.authenticated.value = true;
    await expectLater(ApiService.getJson('/order'), throwsException);
    expect(ApiService.authenticated.value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).containsKey('jwt_token'),
      isFalse,
    );
  });
  test('late 401 leaves a newly installed admin token intact', () async {
    SharedPreferences.setMockInitialValues({});
    final previous = ApiService.client;
    ApiService.client = MockClient((_) async {
      ApiService.setToken('new');
      return http.Response('', 401);
    });
    addTearDown(() {
      ApiService.client = previous;
    });
    ApiService.setToken('old');
    ApiService.authenticated.value = true;
    await expectLater(ApiService.getJson('/order'), throwsException);
    expect(ApiService.authenticated.value, isTrue);
    await ApiService.logout();
  });
}
