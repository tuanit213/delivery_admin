import 'dart:async';
import 'dart:convert';

import 'package:admin/features/auth/screens/login_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Admin form validates role and rejects a stale profile across three sessions',
    (tester) async {
      // Keep consecutive sessions in the same fake async zone, like the running
      // app, because the serialized preferences queue intentionally spans logins.
      for (final scenario in ['admin', 'customer', 'session-changed']) {
        SharedPreferences.setMockInitialValues({});
        await ApiService.logout();
        final original = ApiService.client;
        final profile = Completer<http.Response>();
        var profileRequested = false;
        ApiService.client = MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            expect(jsonDecode(r.body), {
              'email': 'qa-admin',
              'password': 'qa-secret',
            });
            return http.Response(jsonEncode({'accessToken': 'qa-token'}), 200);
          }
          expect(r.url.path.endsWith('/me'), isTrue);
          profileRequested = true;
          return profile.future;
        });
        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (_, _) => const AdminLoginScreen(),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: Text('QA Dashboard')),
            ),
          ],
        );
        addTearDown(() {
          ApiService.client = original;
          router.dispose();
        });
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), 'qa-admin');
        await tester.enterText(find.byType(TextFormField).at(1), 'qa-secret');
        await tester.ensureVisible(find.text('VÀO TRẠM ĐIỀU PHỐI'));
        await tester.tap(find.text('VÀO TRẠM ĐIỀU PHỐI'));
        // The spinner is intentionally still active until the profile arrives.
        for (var i = 0; i < 10 && !profileRequested; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(profileRequested, isTrue);
        if (scenario == 'session-changed') {
          await ApiService.logout();
        }
        profile.complete(
          http.Response(
            jsonEncode({
              'role': scenario == 'customer' ? 'CUSTOMER' : 'ADMIN',
              'userId': 'qa-id',
              'email': 'qa-admin',
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        if (scenario == 'admin') {
          expect(find.text('QA Dashboard'), findsOneWidget);
          expect(ApiService.authenticated.value, isTrue);
          expect(prefs.getString('admin_role'), 'ADMIN');
          expect(prefs.getString('admin_ma_tk'), 'qa-id');
        } else {
          expect(find.text('QA Dashboard'), findsNothing);
          expect(ApiService.authenticated.value, isFalse);
          expect(prefs.containsKey('jwt_token'), isFalse);
          expect(prefs.containsKey('admin_role'), isFalse);
        }
        await ApiService.logout();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
