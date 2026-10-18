import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:admin/services/api_service.dart';
import 'package:admin/features/dashboard/screens/global_search.dart';
import 'package:admin/features/shipper_management/screens/shipper_list_screen.dart';

void main() {
  final drivers = [
    {
      'maSp': 'driver-a',
      'hoTen': 'QA Ship A',
      'soDienThoai': '0900000001',
      'trangThaiHoSo': 'DaDuyet',
      'trangThaiHoatDong': 'OFFLINE',
      'taiTrongToiDa': 30,
    },
    {
      'maSp': 'driver-b',
      'hoTen': 'QA Ship B',
      'soDienThoai': '0900000002',
      'trangThaiHoSo': 'DaDuyet',
      'trangThaiHoatDong': 'OFFLINE',
      'taiTrongToiDa': 30,
    },
  ];
  test('global driver result carries its filter to the destination', () async {
    final previous = ApiService.client;
    ApiService.client = MockClient(
      (request) async => http.Response(
        jsonEncode(request.url.path.endsWith('/shippers') ? drivers : []),
        200,
      ),
    );
    addTearDown(() {
      ApiService.client = previous;
    });
    final search = GlobalSearch();
    addTearDown(search.dispose);
    final results = await search.all();
    final route = Uri.parse(
      results.singleWhere((x) => x['title'] == 'QA Ship B')['route']!,
    );
    expect(route.path, '/shipper_management');
    expect(route.queryParameters['q'], '0900000002');
  });
  testWidgets(
    'driver destination initially shows only the selected search result',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = ApiService.client;
      ApiService.client = MockClient(
        (_) async => http.Response(jsonEncode(drivers), 200),
      );
      addTearDown(() {
        ApiService.client = previous;
      });
      await tester.pumpWidget(
        const MaterialApp(home: ShipperListScreen(initialSearch: '0900000002')),
      );
      await tester.pumpAndSettle();
      expect(find.text('QA Ship A'), findsNothing);
      expect(find.text('QA Ship B'), findsOneWidget);
    },
  );
}
