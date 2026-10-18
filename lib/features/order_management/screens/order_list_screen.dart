import '../../../core/utils/date_time_utils.dart';
import '../../../models/don_hang_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<List<dynamic>> _futureDonHang;
  final ScrollController _horizontalController = ScrollController();

  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureDonHang = ApiService.getDonHangQuanLy();
    });
  }

  String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  double _number(Map<String, dynamic> data, List<String> keys) {
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return vietnamTime(value.toString());
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) return '---';

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  String _formatTimeOnly(DateTime? value) {
    if (value == null) return '';

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.hour)}:${two(value.minute)}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'choxacnhan':
        return Colors.orange;
      case 'choshipperxacnhan':
        return Colors.deepOrange;
      case 'daxacnhan':
        return Colors.indigo;
      case 'danggiao':
      case 'dangvanchuyen':
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

  bool _matchesStatusFilter(String status) {
    final normalized = status.trim().toLowerCase();

    switch (_statusFilter) {
      case 'processing':
        return const {
          'choxacnhan',
          'choshipperxacnhan',
          'daxacnhan',
          'danggiao',
          'dangvanchuyen',
          'candieuphothucong',
        }.contains(normalized);

      case 'completed':
        return const {'dagiao', 'hoanthanh'}.contains(normalized);

      case 'failed':
        return const {
          'dahuy',
          'thatbai',
          'giaothatbai',
          'huytrahang',
          'hoantra',
          'dahoantra',
        }.contains(normalized);

      default:
        return true;
    }
  }

  Widget _statusFilterDropdown() {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: _statusFilter,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'Trạng thái',
          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('Tất cả đơn')),
          DropdownMenuItem(value: 'processing', child: Text('Đang xử lý')),
          DropdownMenuItem(value: 'completed', child: Text('Hoàn tất')),
          DropdownMenuItem(value: 'failed', child: Text('Thất bại / Hủy')),
        ],
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            _statusFilter = value;
          });
        },
      ),
    );
  }

  Widget _routeCell({required String pickup, required String delivery}) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickup.isEmpty ? 'Chưa có địa chỉ lấy' : pickup,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primaryRed,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  delivery.isEmpty ? 'Chưa có địa chỉ giao' : delivery,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danh sách đơn hàng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tra cứu toàn bộ vòng đời đơn hàng, kể cả đơn đã hoàn tất.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _statusFilterDropdown(),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _futureDonHang,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Lỗi kết nối Server:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có đơn hàng nào.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final orders = snapshot.data!.where((raw) {
                  if (raw is! Map) return false;

                  final don = Map<String, dynamic>.from(raw);

                  final status = _text(don, const ['trangThai', 'TrangThai']);

                  return _matchesStatusFilter(status);
                }).toList();

                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có đơn hàng phù hợp với bộ lọc.',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.backgroundGray,
                              ),
                              dataRowMinHeight: 72,
                              dataRowMaxHeight: 92,
                              columnSpacing: 14,
                              horizontalMargin: 14,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Mã đơn',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Người gửi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Người nhận',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tuyến đường',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Phí giao',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'COD',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Trạng thái',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Ngày tạo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Thao tác',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: orders.map((raw) {
                                final don = Map<String, dynamic>.from(
                                  raw as Map,
                                );

                                final maDon = _text(don, [
                                  'maDon',
                                  'maDh',
                                  'maDonHang',
                                  'MaDon',
                                  'MaDh',
                                ], fallback: '---');

                                final tenNguoiGui = _text(don, [
                                  'tenNguoiGui',
                                  'TenNguoiGui',
                                ], fallback: 'Khách hàng');

                                final sdtNguoiGui = _text(don, [
                                  'sdtNguoiGui',
                                  'SdtNguoiGui',
                                  'lienHeLayHang',
                                ]);

                                final tenNguoiNhan = _text(don, [
                                  'tenNguoiNhan',
                                  'TenNguoiNhan',
                                ], fallback: '---');

                                final sdtNguoiNhan = _text(don, [
                                  'sdtNguoiNhan',
                                  'SdtNguoiNhan',
                                  'lienHeGiaoHang',
                                ]);

                                final diaChiLay = _text(don, [
                                  'diaChiLay',
                                  'DiaChiLay',
                                  'diemLayHang',
                                  'DiemLayHang',
                                ]);

                                final diaChiGiao = _text(don, [
                                  'diaChiGiao',
                                  'DiaChiGiao',
                                  'diemGiaoHang',
                                  'DiemGiaoHang',
                                ]);

                                final phiGiaoHang = _number(don, [
                                  'phiGiaoHang',
                                  'PhiGiaoHang',
                                  'giaCuoc',
                                ]);

                                final tienCod = _number(don, [
                                  'tienCod',
                                  'TienCod',
                                  'tienCOD',
                                ]);

                                final trangThai = _text(don, [
                                  'trangThai',
                                  'TrangThai',
                                ], fallback: 'ChoXacNhan');

                                final statusColor = _statusColor(trangThai);
                                final createdAt = _parseDate(
                                  don['ngayTao'] ?? don['NgayTao'],
                                );

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        maDon,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 125,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tenNguoiGui,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (sdtNguoiGui.isNotEmpty)
                                              Text(
                                                sdtNguoiGui,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 125,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tenNguoiNhan,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (sdtNguoiNhan.isNotEmpty)
                                              Text(
                                                sdtNguoiNhan,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _routeCell(
                                        pickup: diaChiLay,
                                        delivery: diaChiGiao,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatMoney(phiGiaoHang),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatMoney(tienCod),
                                        style: const TextStyle(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          adminOrderStatusLabel(trangThai),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 92,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDateOnly(createdAt),
                                              maxLines: 1,
                                            ),
                                            if (_formatTimeOnly(
                                              createdAt,
                                            ).isNotEmpty)
                                              Text(
                                                _formatTimeOnly(createdAt),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Tooltip(
                                        message: 'Xem chi tiết',
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.remove_red_eye_outlined,
                                            color: Colors.blue,
                                          ),
                                          onPressed: maDon == '---'
                                              ? null
                                              : () {
                                                  context.go(
                                                    '/order_detail/$maDon',
                                                  );
                                                },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
