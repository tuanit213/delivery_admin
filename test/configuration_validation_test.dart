import 'dart:convert';
import 'package:admin/features/system_config/screens/config_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<void> mount(WidgetTester tester, void Function() onWrite) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final original = ApiService.client;
    final client = MockClient((r) async {
      if (r.method != 'GET') {
        onWrite();
        return http.Response('{}', 200);
      }
      if (r.url.path.endsWith('peak-hours')) {
        return http.Response(
          jsonEncode([
            {
              'maCd': 'qa-peak',
              'gioBatDau': '07:00:00',
              'gioKetThuc': '09:00:00',
              'heSoPhi': 1.5,
              'isActive': false,
              'cacNgayApDung': '1111100',
            },
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode([
          {'maThamSo': 'PHI_VAN_CHUYEN_CO_BAN', 'giaTri': '15000'},
          {'maThamSo': 'PHI_MOI_KM', 'giaTri': '5000'},
          {'maThamSo': 'THOI_GIAN_CHO_TOI_DA_PHUT', 'giaTri': '5'},
        ]),
        200,
      );
    });
    ApiService.client = client;
    addTearDown(() {
      ApiService.client = original;
      client.close();
    });
    await tester.pumpWidget(const MaterialApp(home: SystemConfigScreen()));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets(
    'cancel restores pricing and waiting parameters as well as peak settings',
    (tester) async {
      var writes = 0;
      await mount(tester, () => writes++);
      await tester.enterText(field('Phí vận chuyển cơ bản (VNĐ)'), '99999');
      await tester.enterText(field('Phí mỗi km (VNĐ/km)'), '999');
      await tester.enterText(field('Thời gian chờ tối đa (phút)'), '9');
      await tester.tap(find.text('Hủy thay đổi'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(field('Phí vận chuyển cơ bản (VNĐ)'))
            .controller
            ?.text,
        '15000',
      );
      expect(
        tester
            .widget<TextFormField>(field('Phí mỗi km (VNĐ/km)'))
            .controller
            ?.text,
        '5000',
      );
      expect(
        tester
            .widget<TextFormField>(field('Thời gian chờ tối đa (phút)'))
            .controller
            ?.text,
        '5',
      );
      expect(writes, 0);
    },
  );

  testWidgets('NaN shipping price cannot write even the peak schedule', (
    tester,
  ) async {
    var writes = 0;
    await mount(tester, () => writes++);
    await tester.enterText(field('Phí vận chuyển cơ bản (VNĐ)'), 'NaN');
    await tester.tap(find.text('Lưu cấu hình'));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets(
    'cancel clears validation errors as well as restoring saved values',
    (tester) async {
      var writes = 0;
      await mount(tester, () => writes++);
      await tester.enterText(field('Phí vận chuyển cơ bản (VNĐ)'), 'NaN');
      await tester.tap(find.text('Lưu cấu hình'));
      await tester.pumpAndSettle();
      expect(find.text('Phí không hợp lệ'), findsOneWidget);
      await tester.tap(find.text('Hủy thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Phí không hợp lệ'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(field('Phí vận chuyển cơ bản (VNĐ)'))
            .controller
            ?.text,
        '15000',
      );
      expect(writes, 0);
    },
  );
}
