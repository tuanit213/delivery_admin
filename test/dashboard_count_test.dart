import 'package:admin/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final value in ['0', '7', '-1', 'not-a-count']) {
    test('shipping counter validates $value', () async {
      final original = ApiService.client;
      ApiService.client = MockClient((_) async => http.Response(value, 200));
      addTearDown(() => ApiService.client = original);
      if (value == '0' || value == '7') {
        expect(await ApiService.getSoLuongDangGiao(), int.parse(value));
      } else {
        await expectLater(
          ApiService.getSoLuongDangGiao(),
          throwsFormatException,
        );
      }
    });
  }
  test(
    'shipping counter outage is reported instead of presenting zero active deliveries',
    () async {
      final original = ApiService.client;
      ApiService.client = MockClient(
        (_) async => http.Response('Unavailable', 503),
      );
      addTearDown(() => ApiService.client = original);
      await expectLater(ApiService.getSoLuongDangGiao(), throwsException);
    },
  );
}
