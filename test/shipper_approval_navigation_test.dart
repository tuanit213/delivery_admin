import 'dart:convert';

import 'package:admin/features/shipper_management/screens/approve_shipper_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets(
    'approval opened with Navigator returns to the driver list after a successful write',
    (tester) async {
      final original = ApiService.client;
      var approved = false;
      final client = MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(
            jsonEncode({'maSp': 'qa-driver', 'hoTen': 'QA Driver'}),
            200,
          );
        }
        expect(r.method, 'POST');
        expect(r.url.path, '/api/identity/shippers/qa-driver/approve');
        expect(jsonDecode(r.body), {'isApproved': true});
        approved = true;
        return http.Response('{}', 200);
      });
      ApiService.client = client;
      addTearDown(() {
        ApiService.client = original;
        client.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ApproveShipperScreen(shipperId: 'qa-driver'),
                  ),
                ),
                child: const Text('QA driver list'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('QA driver list'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Phê duyệt hồ sơ'));
      await tester.tap(find.text('Phê duyệt hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
      expect(find.text('QA driver list'), findsOneWidget);
      expect(find.text('Chi tiết phê duyệt hồ sơ đăng ký mới'), findsNothing);
    },
  );
}
