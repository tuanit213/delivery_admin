import 'dart:convert';
import 'package:admin/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('editing a customer order includes its customer in the quote', () async {
    final previous = ApiService.client;
    final client = MockClient((request) async {
      expect(jsonDecode(request.body)['customerId'], 'customer-with-contract');
      return http.Response(
        jsonEncode({
          'distanceKm': 2,
          'durationMinutes': 4,
          'shippingFee': 17000,
          'routePoints': <Object>[],
        }),
        200,
      );
    });
    ApiService.client = client;
    addTearDown(() {
      ApiService.client = previous;
      client.close();
    });
    final result = await ApiService.getShippingRoute(
      pickupLat: 10.77,
      pickupLng: 106.70,
      deliveryLat: 10.78,
      deliveryLng: 106.71,
      customerId: 'customer-with-contract',
    );
    expect(result.shippingFee, 17000);
  });
  test(
    'Admin preview requests coordinates and preserves exact server distance and price',
    () async {
      final previous = ApiService.client;
      final client = MockClient((r) async {
        expect(r.url.path, '/api/delivery/quote');
        expect(jsonDecode(r.body), {
          'viDoLay': 10.7769,
          'kinhDoLay': 106.7009,
          'viDoGiao': 10.7869,
          'kinhDoGiao': 106.6919,
        });
        return http.Response(
          jsonEncode({
            'distanceKm': 1.944,
            'durationMinutes': 3,
            'shippingFee': 24721,
            'routePoints': [
              {'latitude': 10.7769, 'longitude': 106.7009},
            ],
          }),
          200,
        );
      });
      ApiService.client = client;
      addTearDown(() {
        ApiService.client = previous;
        client.close();
      });
      final quote = await ApiService.getShippingRoute(
        pickupLat: 10.7769,
        pickupLng: 106.7009,
        deliveryLat: 10.7869,
        deliveryLng: 106.6919,
      );
      expect(quote.distanceKm, 1.944);
      expect(quote.shippingFee, 24721);
      expect(quote.routePoints.single.latitude, 10.7769);
    },
  );
  test(
    'Missing/negative route or fee cannot become a successful zero quote',
    () {
      for (final data in <Map<String, dynamic>>[
        {},
        {'distanceKm': 0, 'durationMinutes': 1, 'shippingFee': 100},
        {'distanceKm': 1, 'durationMinutes': 1, 'shippingFee': -1},
        {'distanceKm': 1, 'durationMinutes': 1, 'shippingFee': double.nan},
      ]) {
        expect(() => ShippingRouteData.fromJson(data), throwsFormatException);
      }
    },
  );
}
