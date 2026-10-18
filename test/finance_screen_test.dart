import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin/services/api_service.dart';
import 'package:admin/features/finance/finance_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'invalid commission cannot write; valid commission persists once',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = ApiService.client;
      final writes = <http.Request>[];
      ApiService.client = MockClient((request) async {
        if (request.method == 'PUT') {
          writes.add(request);
          return http.Response(request.body, 200);
        }
        if (request.url.path.endsWith('/earning-policy')) {
          return http.Response('{"commissionPercent":80}', 200);
        }
        return http.Response('[]', 200);
      });
      addTearDown(() {
        ApiService.client = previous;
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FinanceScreen())),
      );
      await tester.pumpAndSettle();
      final percent = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Phần trăm phí giao hàng (%)',
      );
      await tester.enterText(percent, 'NaN');
      await tester.tap(find.text('Lưu tỷ lệ'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.textContaining('Tỷ lệ phải từ 0 đến 100'), findsOneWidget);
      await tester.enterText(percent, '65');
      await tester.tap(find.text('Lưu tỷ lệ'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single.url.path, '/api/finance/earning-policy');
      expect(jsonDecode(writes.single.body)['commissionPercent'], 65);
    },
  );
  testWidgets('finance load error is displayed and loading is released', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = ApiService.client;
    ApiService.client = MockClient(
      (_) async => http.Response('{"message":"Finance unavailable"}', 503),
    );
    addTearDown(() {
      ApiService.client = previous;
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Finance unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
