import 'dart:convert';

import 'package:admin/features/cod_reconciliation/screens/cod_review_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    'double-tap',
    'disposed',
    'session-changed',
    'approve',
  ]) {
    testWidgets('COD confirmation handles $scenario safely', (tester) async {
      SharedPreferences.setMockInitialValues({'admin_ma_tk': 'admin'});
      final original = ApiService.client;
      var writes = 0, show = true;
      late StateSetter redraw;
      ApiService.client = MockClient((r) async {
        if (r.method == 'POST') {
          writes++;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode(
            writes > 0
                ? []
                : [
                    {
                      'maDs': 'qa',
                      'maSp': 'driver',
                      'tongTienNop': 42000,
                      'trangThai': 'ChoDuyet',
                    },
                  ],
          ),
          200,
        );
      });
      addTearDown(() => ApiService.client = original);
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, set) {
              redraw = set;
              return show
                  ? const CodReviewScreen()
                  : const Scaffold(body: Text('Left screen'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Duyệt'),
      );
      button.onPressed!();
      if (scenario == 'double-tap') button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      if (scenario == 'disposed') {
        redraw(() => show = false);
        await tester.pump();
      }
      if (scenario == 'session-changed') {
        ApiService.setToken('different-session');
      }
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Duyệt'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(writes, scenario == 'approve' || scenario == 'double-tap' ? 1 : 0);
      expect(tester.takeException(), isNull);
      if (scenario == 'approve') {
        expect(
          find.text('Không có phiếu đối soát nào đang chờ duyệt.'),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
