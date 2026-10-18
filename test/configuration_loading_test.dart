import 'dart:async';
import 'dart:convert';
import 'package:admin/features/system_config/screens/config_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const peak = [
  {
    'maCd': 'qa',
    'gioBatDau': '07:00:00',
    'gioKetThuc': '09:00:00',
    'heSoPhi': 1.5,
    'isActive': false,
    'cacNgayApDung': '1111100',
  },
];
const parameters = [
  {'maThamSo': 'PHI_VAN_CHUYEN_CO_BAN', 'giaTri': '17000'},
  {'maThamSo': 'PHI_MOI_KM', 'giaTri': '6000'},
  {'maThamSo': 'THOI_GIAN_CHO_TOI_DA_PHUT', 'giaTri': '8'},
];
void main() {
  for (final scenario in ['delayed', 'failed', 'malformed']) {
    testWidgets(
      'configuration cannot save defaults when parameters are $scenario',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = ApiService.client,
            pending = Completer<http.Response>();
        var writes = 0, recovered = false;
        ApiService.client = MockClient((r) async {
          if (r.method != 'GET') {
            writes++;
            return http.Response('{}', 200);
          }
          if (r.url.path.endsWith('peak-hours')) {
            return http.Response(jsonEncode(peak), 200);
          }
          if (scenario == 'delayed' && !recovered) return pending.future;
          if (scenario == 'failed' && !recovered) {
            return http.Response('{}', 503);
          }
          return http.Response(
            jsonEncode(scenario == 'malformed' && !recovered ? {} : parameters),
            200,
          );
        });
        addTearDown(() => ApiService.client = original);
        await tester.pumpWidget(const MaterialApp(home: SystemConfigScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final save = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Lưu cấu hình'),
        );
        if (scenario == 'delayed') {
          expect(save.onPressed, isNull);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          recovered = true;
          pending.complete(http.Response(jsonEncode(parameters), 200));
          await tester.pumpAndSettle();
        } else {
          await tester.pumpAndSettle();
          save.onPressed?.call();
          await tester.pumpAndSettle();
          expect(writes, 0);
          recovered = true;
          await tester.tap(find.text('Thử lại'));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(
                  TextFormField,
                  'Phí vận chuyển cơ bản (VNĐ)',
                ),
              )
              .controller
              ?.text,
          '17000',
        );
        expect(writes, 0);
      },
    );
  }
  for (final scenario in ['empty', 'partial']) {
    testWidgets(
      'new installation with $scenario configuration remains editable',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = ApiService.client;
        final writes = <http.Request>[];
        ApiService.client = MockClient((r) async {
          if (r.method != 'GET') {
            writes.add(r);
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('peak-hours')
                  ? []
                  : scenario == 'partial'
                  ? [parameters.first]
                  : [],
            ),
            200,
          );
        });
        addTearDown(() => ApiService.client = original);
        await tester.pumpWidget(const MaterialApp(home: SystemConfigScreen()));
        await tester.pumpAndSettle();
        Finder field(String label) => find.widgetWithText(TextFormField, label);
        expect(find.text('Thử lại'), findsNothing);
        expect(
          find.textContaining('Chưa có khung giờ cao điểm'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(field('Phí vận chuyển cơ bản (VNĐ)'))
              .controller
              ?.text,
          scenario == 'partial' ? '17000' : '',
        );
        expect(
          tester
              .widget<TextFormField>(field('Phí mỗi km (VNĐ/km)'))
              .controller
              ?.text,
          '',
        );
        await tester.tap(find.text('Lưu cấu hình'));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.enterText(field('Phí vận chuyển cơ bản (VNĐ)'), '17000');
        await tester.enterText(field('Phí mỗi km (VNĐ/km)'), '6000');
        await tester.enterText(field('Thời gian chờ tối đa (phút)'), '8');
        await tester.tap(find.text('Lưu cấu hình'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(4));
        final schedule = writes.singleWhere(
          (r) => r.url.path.endsWith('peak-hours'),
        );
        expect(jsonDecode(schedule.body)['isActive'], false);
        expect(find.textContaining('Chưa có khung giờ cao điểm'), findsNothing);
      },
    );
  }
}
