import 'dart:convert';
import 'package:admin/features/shipper_management/screens/approve_shipper_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final scenario in [
    'double-click',
    'disposed',
    'session-changed',
    'reject-cancel',
  ]) {
    testWidgets('shipper confirmation handles $scenario', (tester) async {
      final original = ApiService.client;
      var writes = 0, show = true;
      late StateSetter redraw;
      ApiService.client = MockClient((r) async {
        if (r.method == 'POST') {
          writes++;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({'maSp': 'qa', 'hoTen': 'QA Driver'}),
          200,
        );
      });
      addTearDown(() {
        ApiService.client = original;
        ApiService.setToken('');
      });
      final router = GoRouter(
        initialLocation: '/approval',
        routes: [
          GoRoute(
            path: '/shipper_management',
            builder: (_, _) => const Scaffold(body: Text('Driver list')),
          ),
          GoRoute(
            path: '/approval',
            builder: (_, _) => StatefulBuilder(
              builder: (_, set) {
                redraw = set;
                return show
                    ? const ApproveShipperScreen(shipperId: 'qa')
                    : const Scaffold(body: Text('Left screen'));
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final label = scenario == 'reject-cancel'
          ? 'Từ chối hồ sơ'
          : 'Phê duyệt hồ sơ';
      await tester.ensureVisible(find.text(label));
      final button = tester.widget<ButtonStyleButton>(
        find.widgetWithText(
          scenario == 'reject-cancel' ? OutlinedButton : ElevatedButton,
          label,
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      if (scenario == 'disposed') {
        redraw(() => show = false);
        await tester.pump();
      }
      if (scenario == 'session-changed') ApiService.setToken('another-session');
      await tester.tap(
        find.text(scenario == 'reject-cancel' ? 'Hủy' : 'Tiếp tục'),
      );
      await tester.pumpAndSettle();
      expect(writes, scenario == 'double-click' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed detail cannot be approved and retry recovers', (
    tester,
  ) async {
    final original = ApiService.client;
    var failed = true, writes = 0;
    ApiService.client = MockClient((r) async {
      if (r.method == 'POST') writes++;
      return failed
          ? http.Response('{}', 503)
          : http.Response('{"maSp":"qa","hoTen":"QA Driver"}', 200);
    });
    addTearDown(() => ApiService.client = original);
    await tester.pumpWidget(
      const MaterialApp(home: ApproveShipperScreen(shipperId: 'qa')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phê duyệt hồ sơ'), findsNothing);
    expect(find.text('Thử lại hồ sơ'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Thử lại hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Phê duyệt hồ sơ'), findsOneWidget);
    expect(writes, 0);
  });
}
