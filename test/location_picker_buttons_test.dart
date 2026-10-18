import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:admin/features/order_management/screens/admin_location_picker_screen.dart';

void main() {
  testWidgets(
    'double confirm returns one location without popping the parent route',
    (tester) async {
      var returns = 0;
      LatLng? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open map'),
                onPressed: () async {
                  selected = await Navigator.of(context).push<LatLng>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AdminLocationPickerScreen(title: 'QA picker'),
                    ),
                  );
                  returns++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Xác nhận'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(returns, 1);
      expect(selected, isA<LatLng>());
      expect(find.text('Open map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
