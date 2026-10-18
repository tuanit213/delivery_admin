import 'dart:async';
import 'dart:convert';

import 'package:admin/features/order_management/screens/order_detail_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response order(String id) => http.Response(
  jsonEncode({
    'maDh': id,
    'tenNguoiNhan': 'Receiver $id',
    'trangThai': 'PENDING',
  }),
  200,
);
void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Admin order detail fits width $width with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = ApiService.client;
      ApiService.client = MockClient(
        (_) async => order('431d78e5-3155-43fb-82ac-71ba0aaea34b'),
      );
      addTearDown(() => ApiService.client = original);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: OrderDetailScreen(orderId: 'qa')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'changing Admin detail ID clears the old order before the new response arrives',
    (tester) async {
      final original = ApiService.client;
      final next = Completer<http.Response>();
      ApiService.client = MockClient(
        (r) async => r.url.path.endsWith('/a') ? order('a') : next.future,
      );
      addTearDown(() => ApiService.client = original);
      Widget app(String id) => MaterialApp(
        home: Scaffold(body: OrderDetailScreen(orderId: id)),
      );
      await tester.pumpWidget(app('a'));
      await tester.pumpAndSettle();
      expect(find.text('Receiver a'), findsOneWidget);
      await tester.pumpWidget(app('b'));
      await tester.pump();
      expect(find.text('Receiver a'), findsNothing);
      next.complete(order('b'));
      await tester.pumpAndSettle();
      expect(find.text('Receiver b'), findsOneWidget);
    },
  );
  for (final lateError in [false, true]) {
    testWidgets(
      'old detail ${lateError ? 'failure' : 'success'} cannot overwrite the newly selected order',
      (tester) async {
        final original = ApiService.client;
        final first = Completer<http.Response>();
        ApiService.client = MockClient(
          (r) async => r.url.path.endsWith('/a') ? first.future : order('b'),
        );
        addTearDown(() => ApiService.client = original);
        Widget app(String id) => MaterialApp(
          home: Scaffold(body: OrderDetailScreen(orderId: id)),
        );
        await tester.pumpWidget(app('a'));
        await tester.pump();
        await tester.pumpWidget(app('b'));
        await tester.pumpAndSettle();
        first.complete(
          lateError ? http.Response('Unreachable old order', 503) : order('a'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Receiver b'), findsOneWidget);
        expect(find.text('Receiver a'), findsNothing);
        expect(find.textContaining('Không thể'), findsNothing);
      },
    );
  }
}
