import 'package:admin/models/don_hang_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispatch model reads the persisted OrderService road distance', () {
    final order = DonHangModel.fromJson({
      'maDh': 'qa-order',
      'trangThai': 'PENDING',
      'khoiLuong': 2,
      'khoangCach': 1.944,
      'phiGiaoHang': 24721,
    });
    expect(order.quangDuongKm, 1.944);
    expect(order.trongLuong, 2);
    expect(order.giaCuoc, '24721');
    expect(order.trangThai, 'ChoXacNhan');
  });
}
