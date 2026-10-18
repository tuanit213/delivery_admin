import 'dart:async';
import 'dart:convert';
import 'package:admin/features/finance/finance_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = ApiService.client;
    ApiService.client = MockClient(handler);
    addTearDown(() => ApiService.client = original);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  http.Response response(Object data) => http.Response(jsonEncode(data), 200);

  testWidgets(
    'salary selection locks during loading and clears previous data on failed selection',
    (tester) async {
      final pending = Completer<http.Response>();
      await mount(tester, (r) async {
        if (r.url.path.endsWith('/shippers')) {
          return response([
            {'maSp': 'a', 'hoTen': 'Driver A'},
            {'maSp': 'b', 'hoTen': 'Driver B'},
          ]);
        }
        if (r.url.path.endsWith('/earning-policy')) {
          return response({'commissionPercent': 80});
        }
        if (r.url.path.endsWith('/salary/a')) return pending.future;
        if (r.url.path.endsWith('/salary/b')) return http.Response('{}', 503);
        return response([]);
      });
      Finder dropdown() => find.byType(DropdownButtonFormField<String>).first;
      tester.widget<DropdownButtonFormField<String>>(dropdown()).onChanged!(
        'a',
      );
      await tester.pump();
      expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown()).onChanged,
        isNull,
      );
      pending.complete(
        response({
          'month': 10,
          'year': 2026,
          'deliveryCount': 1,
          'totalEarnings': 12345,
          'items': [],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('12345'), findsOneWidget);
      tester.widget<DropdownButtonFormField<String>>(dropdown()).onChanged!(
        'b',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('12345'), findsNothing);
      expect(find.textContaining('HTTP 503'), findsOneWidget);
      await tester.tap(find.text('Tải lại dữ liệu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 503'), findsNothing);
    },
  );

  testWidgets(
    'contract rejects normalized invalid dates and missing customer',
    (tester) async {
      final writes = <http.Request>[];
      await mount(tester, (r) async {
        if (r.method == 'PUT') {
          writes.add(r);
          return response({});
        }
        if (r.url.path.endsWith('/earning-policy')) {
          return response({'commissionPercent': 80});
        }
        return response([]);
      });
      await tester.enterText(field('Mã hợp đồng'), 'QA');
      await tester.enterText(
        field('Hiệu lực đến ngày (YYYY-MM-DD)'),
        '2026-02-31',
      );
      await tester.tap(find.text('Lưu hợp đồng'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.enterText(
        field('Hiệu lực đến ngày (YYYY-MM-DD)'),
        '2027-02-28',
      );
      await tester.tap(find.text('Lưu hợp đồng'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.enterText(field('Mã khách hàng (UUID)'), 'qa-customer');
      await tester.tap(find.text('Lưu hợp đồng'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(
        jsonDecode(writes.single.body)['validUntil'],
        '2027-02-28T23:59:59.999999Z',
      );
    },
  );
}
