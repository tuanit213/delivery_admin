import '../../../core/utils/date_time_utils.dart';
import '../../../models/don_hang_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _orderDetail;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  @override
  void didUpdateWidget(covariant OrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _fetchOrderDetail();
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  Future<void> _fetchOrderDetail() async {
    final requestId = ++_requestId;
    final orderId = widget.orderId;
    setState(() {
      _isLoading = true;
      _error = null;
      _orderDetail = null;
    });

    try {
      final data = await ApiService.getChiTietDonHang(orderId);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _orderDetail = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _text(List<String> keys, {String fallback = '---'}) {
    final data = _orderDetail;

    if (data == null) return fallback;

    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return fallback;
  }

  double _number(List<String> keys) {
    final data = _orderDetail;

    if (data == null) return 0;

    for (final key in keys) {
      final value = data[key];

      if (value is num) return value.toDouble();

      if (value != null) {
        final parsed = double.tryParse(value.toString());

        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  String _formatMoney(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} đ';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '---';

    final parsed = vietnamTime(value.toString());

    if (parsed == null) return value.toString();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'choxacnhan':
        return Colors.orange;
      case 'danggiao':
        return Colors.blue;
      case 'dagiao':
      case 'hoanthanh':
        return Colors.green;
      case 'thatbai':
      case 'giaothatbai':
      case 'dahuy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _infoBox({
    required String title,
    required String name,
    required String phone,
    required String address,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _line(Icons.person_outline, name),
          const SizedBox(height: 10),
          _line(Icons.phone_outlined, phone),
          const SizedBox(height: 10),
          _line(Icons.location_on_outlined, address),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(value, style: const TextStyle(height: 1.4)),
        ),
      ],
    );
  }

  Widget _metric({
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSubtitle,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchOrderDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final maDon = _text([
      'maDh',
      'maDon',
      'maDonHang',
      'MaDh',
    ], fallback: widget.orderId);

    final trangThai = _text(['trangThai', 'TrangThai'], fallback: '---');

    final ngayTaoRaw =
        _orderDetail?['ngayTao'] ??
        _orderDetail?['NgayTao'] ??
        _orderDetail?['thoiGianTao'];

    final tenNguoiGui = _text([
      'tenNguoiGui',
      'TenNguoiGui',
    ], fallback: 'Khách hàng');

    final sdtNguoiGui = _text(['sdtNguoiGui', 'SdtNguoiGui', 'lienHeLayHang']);

    final tenNguoiNhan = _text(['tenNguoiNhan', 'TenNguoiNhan']);

    final sdtNguoiNhan = _text([
      'sdtNguoiNhan',
      'SdtNguoiNhan',
      'lienHeGiaoHang',
    ]);

    final diaChiLay = _text(['diaChiLay', 'DiaChiLay', 'diemLayHang']);

    final diaChiGiao = _text(['diaChiGiao', 'DiaChiGiao', 'diemGiaoHang']);

    final khoiLuong = _number(['khoiLuong', 'KhoiLuong', 'trongLuong']);

    final kichThuoc = _text(['kichThuoc', 'KichThuoc']);

    final tienCod = _number(['tienCod', 'TienCod', 'tienCOD']);

    final phiGiaoHang = _number(['phiGiaoHang', 'PhiGiaoHang', 'giaCuoc']);

    final quangDuongKm = _number([
      'khoangCach',
      'KhoangCach',
      'quangDuongKm',
      'QuangDuongKm',
      'distanceKm',
    ]);

    final duKienGiaoPhut = _number([
      'duKienGiaoPhut',
      'DuKienGiaoPhut',
      'durationMinutes',
    ]);

    final maKh = _text([
      'maKh',
      'MaKh',
      'customerId',
    ], fallback: 'Khách vãng lai');

    final maSp = _text([
      'maSp',
      'MaSp',
      'maShipper',
    ], fallback: 'Chưa phân công');

    final statusColor = _statusColor(trangThai);

    return Container(
      color: const Color(0xFFF5F1E5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Quay lại danh sách',
                  onPressed: () => context.go('/order_management'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết đơn hàng $maDon',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngày tạo: ${_formatDate(ngayTaoRaw)}',
                        style: const TextStyle(color: AppColors.textSubtitle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                adminOrderStatusLabel(trangThai),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final sender = _infoBox(
                  title: 'Thông tin người gửi',
                  name: tenNguoiGui,
                  phone: sdtNguoiGui,
                  address: diaChiLay,
                  icon: Icons.unarchive_outlined,
                );
                final recipient = _infoBox(
                  title: 'Thông tin người nhận',
                  name: tenNguoiNhan,
                  phone: sdtNguoiNhan,
                  address: diaChiGiao,
                  icon: Icons.archive_outlined,
                );
                return constraints.maxWidth < 720
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          sender,
                          const SizedBox(height: 18),
                          recipient,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: sender),
                          const SizedBox(width: 18),
                          Expanded(child: recipient),
                        ],
                      );
              },
            ),

            const SizedBox(height: 18),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 24,
                  children: [
                    _metric(
                      label: 'Khối lượng',
                      value: '${khoiLuong.toStringAsFixed(2)} kg',
                      icon: Icons.scale_outlined,
                    ),
                    _metric(
                      label: 'Kích thước',
                      value: kichThuoc,
                      icon: Icons.straighten_outlined,
                    ),
                    _metric(
                      label: 'Quãng đường',
                      value: quangDuongKm > 0
                          ? '${quangDuongKm.toStringAsFixed(2)} km'
                          : '---',
                      icon: Icons.route_outlined,
                    ),
                    _metric(
                      label: 'Dự kiến giao',
                      value: duKienGiaoPhut > 0
                          ? '${duKienGiaoPhut.round()} phút'
                          : '---',
                      icon: Icons.schedule_outlined,
                    ),
                    _metric(
                      label: 'Tiền COD',
                      value: _formatMoney(tienCod),
                      icon: Icons.payments_outlined,
                      valueColor: AppColors.primaryRed,
                    ),
                    _metric(
                      label: 'Phí vận chuyển',
                      value: _formatMoney(phiGiaoHang),
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 48,
                  runSpacing: 18,
                  children: [
                    _metric(
                      label: 'Mã khách hàng',
                      value: maKh,
                      icon: Icons.person_outline,
                    ),
                    _metric(
                      label: 'Tài xế phụ trách',
                      value: maSp,
                      icon: Icons.delivery_dining_outlined,
                    ),
                    _metric(
                      label: 'Mã đơn',
                      value: maDon,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
