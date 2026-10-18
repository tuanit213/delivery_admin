import 'dart:convert';
import 'package:admin/features/dispatch_center/screens/dispatch_center_screen.dart';
import 'package:admin/features/shipper_management/screens/shipper_list_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final action in ['delete', 'offline']) {
    for (final scenario in [
      'double-click',
      'cancel',
      'disposed',
      'session-changed',
    ]) {
      testWidgets('$action confirmation handles $scenario', (tester) async {
        tester.view.physicalSize = const Size(1600, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = ApiService.client;
        var writes = 0, show = true;
        late StateSetter redraw;
        ApiService.client = MockClient((r) async {
          if (r.method != 'GET') {
            writes++;
            return http.Response('{}', 200);
          }
          final Object data;
          if (r.url.path.endsWith('/order')) {
            data = [
              {
                'maDh': 'qa-order',
                'trangThai': 'PENDING',
                'tenNguoiGui': 'QA Sender',
                'khoiLuong': 1,
                'diaChiLay': 'QA pickup',
                'diaChiGiao': 'QA delivery',
                'tienCod': 0,
              },
            ];
          } else if (r.url.path.endsWith('/shippers')) {
            data = [
              {
                'maSp': 'qa-driver',
                'hoTen': 'QA Driver',
                'trangThaiHoSo': 'DaDuyet',
                'trangThaiHoatDong': 'ONLINE',
                'taiTrongToiDa': 20,
                'taiTrongConLai': 20,
              },
            ];
          } else {
            data = [];
          }
          return http.Response(jsonEncode(data), 200);
        });
        addTearDown(() {
          ApiService.client = original;
          ApiService.setToken('');
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, set) {
                  redraw = set;
                  return show
                      ? (action == 'delete'
                            ? const DispatchCenterScreen()
                            : const ShipperListScreen())
                      : const Text('Left screen');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final VoidCallback handler;
        if (action == 'delete') {
          handler = tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Xóa đơn',
                ),
              )
              .onPressed!;
        } else {
          handler = tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Ngắt kết nối'),
              )
              .onPressed!;
        }
        handler();
        handler();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        if (scenario == 'disposed') {
          redraw(() => show = false);
          await tester.pump();
        }
        if (scenario == 'session-changed') {
          ApiService.setToken('different-session');
        }
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              scenario == 'cancel'
                  ? 'Hủy'
                  : action == 'delete'
                  ? 'Xóa đơn'
                  : 'Ngắt kết nối',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(writes, scenario == 'double-click' ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      });
    }
  }
}
