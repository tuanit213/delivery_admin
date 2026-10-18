import 'dart:async';
import 'dart:convert';

import 'package:admin/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String token(String id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client original;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.logout();
    original = ApiService.client;
  });
  tearDown(() async {
    ApiService.client = original;
    await ApiService.logout();
  });

  test(
    'old successful read cannot expose the previous admin session',
    () async {
      final reply = Completer<http.Response>();
      ApiService.client = MockClient((_) => reply.future);
      ApiService.setToken(token('old'));
      final pending = ApiService.getJson('/order');
      final assertion = expectLater(
        pending,
        throwsA(isA<AdminSessionChangedException>()),
      );
      ApiService.setToken(token('new'));
      reply.complete(http.Response('[{"maDh":"private-old-order"}]', 200));
      await assertion;
    },
  );

  test('logout and reusing a token still invalidates pending work', () async {
    final reply = Completer<http.Response>();
    ApiService.client = MockClient((_) => reply.future);
    final value = token('same');
    ApiService.setToken(value);
    final pending = ApiService.getJson('/order');
    final assertion = expectLater(
      pending,
      throwsA(isA<AdminSessionChangedException>()),
    );
    await ApiService.logout();
    ApiService.setToken(value);
    reply.complete(http.Response('[]', 200));
    await assertion;
  });

  test(
    'session checks cover delayed response bodies as well as headers',
    () async {
      final body = StreamController<List<int>>();
      final receivedHeaders = Completer<void>();
      ApiService.client = MockClient.streaming((_, _) async {
        receivedHeaders.complete();
        return http.StreamedResponse(body.stream, 200);
      });
      ApiService.setToken(token('old'));
      final pending = ApiService.getJson('/order');
      final assertion = expectLater(
        pending,
        throwsA(isA<AdminSessionChangedException>()),
      );
      await receivedHeaders.future;
      ApiService.setToken(token('new'));
      body.add(utf8.encode('[]'));
      await body.close();
      await assertion;
    },
  );

  test('the newest login attempt wins even when it is rejected', () async {
    final first = Completer<http.Response>(),
        second = Completer<http.Response>();
    var calls = 0;
    ApiService.client = MockClient(
      (_) => ++calls == 1 ? first.future : second.future,
    );
    final old = ApiService.login('old@example.test', 'mock-only');
    final oldAssertion = expectLater(
      old,
      throwsA(isA<AdminSessionChangedException>()),
    );
    final newest = ApiService.login('new@example.test', 'mock-only');
    final newAssertion = expectLater(newest, throwsException);
    second.complete(http.Response('{}', 401));
    await newAssertion;
    first.complete(
      http.Response(jsonEncode({'accessToken': token('old')}), 200),
    );
    await oldAssertion;
    expect(
      (await SharedPreferences.getInstance()).getString('jwt_token'),
      isNull,
    );
  });

  test('pending logout cannot remove a newer saved login', () async {
    final freshToken = token('new');
    ApiService.client = MockClient(
      (_) async => http.Response(jsonEncode({'accessToken': freshToken}), 200),
    );
    ApiService.setToken(token('old'));
    final signingOut = ApiService.logout();
    final signingIn = ApiService.login('new@example.test', 'mock-only');
    await signingOut;
    await signingIn;
    expect(
      (await SharedPreferences.getInstance()).getString('jwt_token'),
      freshToken,
    );
  });

  test('restoring the client does not stack transport wrappers', () async {
    var calls = 0;
    ApiService.client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final saved = ApiService.client;
    ApiService.client = saved;
    await ApiService.getJson('/identity/me');
    expect(calls, 1);
  });

  test('a delayed network error belongs to its original session', () async {
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    ApiService.client = MockClient((_) {
      started.complete();
      return reply.future;
    });
    ApiService.setToken(token('old'));
    final pending = ApiService.getJson('/order');
    final assertion = expectLater(
      pending,
      throwsA(isA<AdminSessionChangedException>()),
    );
    await started.future;
    ApiService.setToken(token('new'));
    reply.completeError(http.ClientException('old connection failed'));
    await assertion;
  });

  testWidgets(
    'all transport reads have a deadline even without a method timeout',
    (tester) async {
      final reply = Completer<http.Response>();
      ApiService.client = MockClient((_) => reply.future);
      final pending = ApiService.client.get(
        Uri.parse('https://example.test/never-responds'),
      );
      final assertion = expectLater(pending, throwsA(isA<TimeoutException>()));
      await tester.pump(const Duration(seconds: 21));
      await assertion;
      reply.complete(http.Response('{}', 200));
      await tester.pump();
    },
  );
}
