import 'dart:async';

import 'package:admin/models/don_hang_model.dart';
import 'package:admin/models/shipper_model.dart';
import 'package:admin/services/admin_notification_service.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';

import '../../order_management/screens/admin_create_order_screen.dart';

class DispatchCenterScreen extends StatefulWidget {
  const DispatchCenterScreen({super.key});

  @override
  State<DispatchCenterScreen> createState() => _DispatchCenterScreenState();
}

class _DispatchCenterScreenState extends State<DispatchCenterScreen> {
  final Color primaryRed = const Color(0xFF245B69);
  final Color bgCream = const Color(0xFFF9F6F0);

  List<DonHangModel> _pendingOrders = [];
  List<ShipperModel> _recommendedShippers = [];
  DonHangModel? _selectedOrder;

  bool _isLoading = true;
  bool _onlyAssignable = false;
  bool _isAssigning = false;
  String? _errorMessage;

  // Fallback 5 phút nếu backend chưa có tham số.
  int _maxWaitingMinutes = 5;

  final Set<String> _notifiedOverdueOrderIds = <String>{};

  final Map<String, ShipperPickupRouteData> _shipperPickupRoutes = {};
  final Set<String> _loadingShipperRouteIds = <String>{};

  int _shipperRouteRequestId = 0;

  bool _hasPerformedInitialOverdueCheck = false;

  bool _isDeletingOrder = false;
  bool _confirmingDelete = false;

  Timer? _waitingTimer;

  @override
  void initState() {
    super.initState();
    _fetchDataFromApi();

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      _checkOverdueNotifications();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDataFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getDonHangChoNhan(),
        ApiService.getDanhSachShipper(),
        ApiService.getThamSoHeThong(),
      ]);

      final List<DonHangModel> loadedOrders = (results[0] as List)
          .map((json) => DonHangModel.fromJson(json as Map<String, dynamic>))
          .toList();

      final List<ShipperModel> loadedShippers = (results[1] as List)
          .map((json) => ShipperModel.fromJson(json as Map<String, dynamic>))
          .where((shipper) {
            final approvalStatus = shipper.trangThaiDuyet.trim().toLowerCase();

            final isApproved =
                approvalStatus == 'daduyet' || approvalStatus == 'da_duyet';

            return isApproved && shipper.isOnline;
          })
          .toList();

      int loadedMaxWaitingMinutes = 5;
      final rawParams = results[2];

      if (rawParams is List) {
        for (final item in rawParams) {
          if (item is! Map) continue;

          final map = Map<String, dynamic>.from(item);
          final key = (map['maThamSo'] ?? map['MaThamSo'] ?? '')
              .toString()
              .trim();

          if (key != 'THOI_GIAN_CHO_TOI_DA_PHUT') continue;

          final rawValue = (map['giaTri'] ?? map['GiaTri'] ?? '')
              .toString()
              .trim();
          final parsed = int.tryParse(rawValue);

          if (parsed != null && parsed > 0) {
            loadedMaxWaitingMinutes = parsed;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pendingOrders = loadedOrders;
        _selectedOrder = loadedOrders.isNotEmpty ? loadedOrders.first : null;
        _recommendedShippers = loadedShippers;
        _maxWaitingMinutes = loadedMaxWaitingMinutes;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkOverdueNotifications();
        _refreshShipperPickupRoutes();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshShipperPickupRoutes() async {
    final order = _selectedOrder;

    if (order == null || !order.hasValidPickupLocation) {
      if (!mounted) return;

      setState(() {
        _shipperPickupRoutes.clear();
        _loadingShipperRouteIds.clear();
      });
      return;
    }

    final requestId = ++_shipperRouteRequestId;
    final pickupLat = order.pickupLatitude!;
    final pickupLng = order.pickupLongitude!;

    final eligibleShippers = _recommendedShippers
        .where(
          (shipper) =>
              shipper.isOnline &&
              shipper.hasValidLocation &&
              !shipper.isLocationStale,
        )
        .toList();

    setState(() {
      _shipperPickupRoutes.clear();
      _loadingShipperRouteIds
        ..clear()
        ..addAll(eligibleShippers.map((shipper) => shipper.id));
    });

    await Future.wait(
      eligibleShippers.map((shipper) async {
        final route = await OsrmService.getShipperToPickupRoute(
          shipperLat: shipper.lat!,
          shipperLng: shipper.lng!,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
        );

        if (!mounted || requestId != _shipperRouteRequestId) {
          return;
        }

        setState(() {
          _loadingShipperRouteIds.remove(shipper.id);

          if (route != null) {
            _shipperPickupRoutes[shipper.id] = route;
          } else {
            _shipperPickupRoutes.remove(shipper.id);
          }
        });
      }),
    );
  }

  void _selectOrder(DonHangModel order) {
    setState(() {
      _selectedOrder = order;
    });

    _refreshShipperPickupRoutes();
  }

  String _formatRouteDistance(ShipperModel shipper) {
    if (!shipper.isOnline) return '--';
    if (!shipper.hasValidLocation) return 'Chưa có GPS';
    if (shipper.isLocationStale) return 'GPS cũ';
    if (_loadingShipperRouteIds.contains(shipper.id)) {
      return 'Đang tính...';
    }

    final route = _shipperPickupRoutes[shipper.id];

    if (route == null) return 'Không có route';

    return '${route.distanceKm.toStringAsFixed(1)} km';
  }

  String _formatShipperIdleTime(ShipperModel shipper) {
    if (!shipper.isOnline) {
      return '--';
    }

    if (!shipper.dangRanh) {
      if (shipper.dangCoDonHoatDong) {
        return 'Đang có đơn';
      }

      return 'Không rảnh';
    }

    final elapsed = shipper.idleDurationNow;

    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    String two(int value) => value.toString().padLeft(2, '0');

    if (hours == 0 && minutes == 0) {
      return '${two(seconds)} giây';
    }

    if (hours == 0) {
      return '$minutes phút ${two(seconds)} giây';
    }

    // Từ 1 giờ trở lên: 1 giờ 05 phút.
    return '$hours giờ ${two(minutes)} phút';
  }

  Color _shipperIdleColor(ShipperModel shipper) {
    if (!shipper.isOnline) {
      return Colors.grey;
    }

    if (!shipper.dangRanh) {
      return Colors.orange.shade700;
    }

    return primaryRed;
  }

  bool _canAssignSelectedOrderTo(ShipperModel shipper) {
    final order = _selectedOrder;

    if (order == null) return false;

    return shipper.canAcceptWeight(order.trongLuong);
  }

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _capacityText(ShipperModel shipper) {
    return '${_formatWeight(shipper.taiTrongDangNhan)} / '
        '${_formatWeight(shipper.taiTrongToiDa)} kg';
  }

  String _capacitySubText(ShipperModel shipper) {
    final order = _selectedOrder;

    if (order == null) {
      return 'Còn ${_formatWeight(shipper.taiTrongConLai)} kg';
    }

    if (_canAssignSelectedOrderTo(shipper)) {
      return 'Còn ${_formatWeight(shipper.taiTrongConLai)} kg';
    }

    return 'Đơn ${_formatWeight(order.trongLuong)} kg vượt tải';
  }

  Future<void> _assignOrderToShipper(ShipperModel shipper) async {
    if (_selectedOrder == null || _isAssigning) return;
    final assignedOrder = _selectedOrder!;

    if (!_canAssignSelectedOrderTo(shipper)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể chỉ định ${shipper.hoTen}: '
            'tổng tải sau khi nhận phải nhỏ hơn '
            '${_formatWeight(shipper.taiTrongToiDa)} kg.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isAssigning = true;
    });

    try {
      final success = await ApiService.phanDon(assignedOrder.maDon, shipper.id);

      if (!mounted) return;

      if (!success) {
        throw Exception('Backend không xác nhận thao tác chỉ định Shipper.');
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã chỉ định ${shipper.hoTen}. Đang chờ Shipper xác nhận!',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {
          _pendingOrders.removeWhere((o) => o.maDon == assignedOrder.maDon);
          _notifiedOverdueOrderIds.remove(_orderKey(assignedOrder));
          _selectedOrder = _pendingOrders.isNotEmpty
              ? _pendingOrders.first
              : null;
        });

        await _fetchDataFromApi();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phân đơn thất bại: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: bgCream,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryRed),
              const SizedBox(height: 16),
              const Text(
                'Đang tải dữ liệu điều phối từ Server...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: bgCream,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: _fetchDataFromApi,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: bgCream,
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1080) {
                return DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Hàng chờ'),
                          Tab(text: 'Chi tiết đơn'),
                          Tab(text: 'Shipper'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildPendingOrdersColumn(),
                            _buildOrderDetailColumn(),
                            _buildShipperRecommendationsColumn(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 330, child: _buildPendingOrdersColumn()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildOrderDetailColumn()),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 340,
                    child: _buildShipperRecommendationsColumn(),
                  ),
                ],
              );
            },
          ),
        ),
        if (_isAssigning)
          Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryRed),
                      const SizedBox(height: 12),
                      const Text(
                        'Đang chỉ định Shipper...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Duration _waitingDuration(DonHangModel order) {
    final createdAt = order.ngayTao;

    if (createdAt == null) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(createdAt);

    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  String _orderKey(DonHangModel order) {
    final maDon = order.maDon.trim();

    if (maDon.isNotEmpty) {
      return maDon;
    }

    return order.id.trim();
  }

  void _checkOverdueNotifications() {
    if (!mounted || _isLoading || _pendingOrders.isEmpty) {
      return;
    }

    final overdueOrders = _pendingOrders.where(_isOrderOverdue).toList();

    if (!_hasPerformedInitialOverdueCheck) {
      _hasPerformedInitialOverdueCheck = true;

      for (final order in overdueOrders) {
        final key = _orderKey(order);

        if (key.isNotEmpty) {
          _notifiedOverdueOrderIds.add(key);

          AdminNotificationService.instance.addOrderOverdue(
            orderId: key,
            maxWaitingMinutes: _maxWaitingMinutes,
            elapsed: _waitingDuration(order),
          );
        }
      }

      if (overdueOrders.isNotEmpty) {
        final count = overdueOrders.length;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: primaryRed,
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      count == 1
                          ? 'Có 1 đơn đã quá thời gian chờ điều phối.'
                          : 'Có $count đơn đã quá thời gian chờ điều phối.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      }

      return;
    }

    for (final order in overdueOrders) {
      final key = _orderKey(order);

      if (key.isEmpty || _notifiedOverdueOrderIds.contains(key)) {
        continue;
      }

      _notifiedOverdueOrderIds.add(key);

      AdminNotificationService.instance.addOrderOverdue(
        orderId: key,
        maxWaitingMinutes: _maxWaitingMinutes,
        elapsed: _waitingDuration(order),
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đơn ${order.maDon} đã chờ quá '
                    '$_maxWaitingMinutes phút. '
                    'Cần điều phối thủ công.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'XEM',
              textColor: Colors.white,
              onPressed: () {
                if (!mounted) return;

                _selectOrder(order);
              },
            ),
          ),
        );
    }

    final currentPendingKeys = _pendingOrders
        .map(_orderKey)
        .where((key) => key.isNotEmpty)
        .toSet();

    _notifiedOverdueOrderIds.removeWhere(
      (key) => !currentPendingKeys.contains(key),
    );
  }

  Widget _buildPendingOrdersColumn() {
    final urgentOrders = _pendingOrders.where(_isOrderOverdue).toList();
    final normalOrders = _pendingOrders
        .where((o) => !_isOrderOverdue(o))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sách hàng chờ',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_pendingOrders.length} đơn',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Tải lại danh sách',
              onPressed: _fetchDataFromApi,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _pendingOrders.isEmpty
              ? const Center(
                  child: Text(
                    'Không có đơn hàng nào chờ điều phối',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView(
                  children: [
                    if (urgentOrders.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            '* ',
                            style: TextStyle(
                              color: primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Cần điều phối thủ công (>$_maxWaitingMinutes phút)',
                            style: TextStyle(
                              color: primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...urgentOrders.map((order) => _buildOrderCard(order)),
                      const SizedBox(height: 12),
                    ],
                    if (normalOrders.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'CHỜ PHÂN CÔNG TỰ ĐỘNG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...normalOrders.map((order) => _buildOrderCard(order)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _formatWaitingTime(DonHangModel order) {
    final createdAt = order.ngayTao;

    if (createdAt == null) {
      return order.thoiGianCho;
    }

    final now = DateTime.now();
    var elapsed = now.difference(createdAt);

    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    String two(int value) => value.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    }

    return '${two(minutes)}:${two(seconds)}';
  }

  bool _isOrderOverdue(DonHangModel order) {
    final createdAt = order.ngayTao;

    if (createdAt == null) {
      return false;
    }

    final elapsed = DateTime.now().difference(createdAt);

    if (elapsed.isNegative) {
      return false;
    }

    return elapsed >= Duration(minutes: _maxWaitingMinutes);
  }

  Widget _buildOrderCard(DonHangModel order) {
    final isSelected =
        _selectedOrder?.maDon == order.maDon || _selectedOrder?.id == order.id;
    final isOverdue = _isOrderOverdue(order);

    return GestureDetector(
      onTap: () => _selectOrder(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: isSelected ? primaryRed : const Color(0xFFCDD4CC),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.maDon,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOverdue ? primaryRed : Colors.black87,
                  ),
                ),
                Text(
                  _formatWaitingTime(order),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? primaryRed : Colors.grey,
                  ),
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  'QUÁ THỜI GIAN CHỜ',
                  style: TextStyle(
                    color: primaryRed,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.scale_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.trongLuong} kg',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(order.kichThuoc, style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.diemLayHang,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: primaryRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.diemGiaoHang,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditOrder(DonHangModel order) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateOrderScreen(editOrderId: order.maDon),
      ),
    );

    if (updated != true || !mounted) return;

    await _fetchDataFromApi();

    if (!mounted) return;

    DonHangModel? edited;
    for (final item in _pendingOrders) {
      if (item.maDon == order.maDon) {
        edited = item;
        break;
      }
    }

    if (edited != null) {
      setState(() => _selectedOrder = edited);
      await _refreshShipperPickupRoutes();
    }
  }

  Future<void> _confirmDeleteOrder(DonHangModel order) async {
    if (_isDeletingOrder || _confirmingDelete) return;
    final revision = ApiService.sessionRevision;
    _confirmingDelete = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa đơn hàng?'),
          content: Text(
            'Bạn có chắc muốn xóa đơn ${order.maDon}?\n\n'
            'Thao tác này chỉ áp dụng cho đơn đang Chờ xác nhận '
            'và chưa được phân Shipper.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Xóa đơn'),
            ),
          ],
        );
      },
    );

    _confirmingDelete = false;
    if (confirmed != true ||
        !mounted ||
        revision != ApiService.sessionRevision) {
      return;
    }

    setState(() => _isDeletingOrder = true);

    try {
      await ApiService.adminXoaDon(order.maDon);

      if (!mounted) return;

      await _fetchDataFromApi();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa đơn ${order.maDon}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Xóa đơn thất bại: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingOrder = false);
      }
    }
  }

  Widget _buildOrderDetailColumn() {
    final order = _selectedOrder;

    if (order == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: const Center(child: Text('Không có đơn hàng nào được chọn')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFCDD4CC)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết đơn hàng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      order.maDon,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryRed,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Chỉnh sửa đơn',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: _isDeletingOrder
                          ? null
                          : () => _openEditOrder(order),
                    ),
                    IconButton(
                      tooltip: 'Xóa đơn',
                      icon: _isDeletingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                      onPressed: _isDeletingOrder
                          ? null
                          : () => _confirmDeleteOrder(order),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THÔNG SỐ KĨ THUẬT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSpecRow(
                        'Trọng lượng:',
                        '${order.trongLuong.toStringAsFixed(2)} kg',
                      ),
                      _buildSpecRow('Kích thước:', order.kichThuoc),
                      _buildSpecRow(
                        'Dung tích:',
                        order.dungTich > 0 ? '${order.dungTich} m³' : 'Chưa có',
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 75,
                            child: Text(
                              'Tính chất:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              order.tinhChat,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THỜI GIAN & CHI PHÍ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSpecRow(
                        'Dự kiến giao:',
                        order.duKienGiaoPhut > 0
                            ? '${order.duKienGiaoPhut} phút'
                            : 'Chưa có dự kiến',
                        highlightValue: true,
                      ),
                      _buildSpecRow('Giá cước:', order.giaCuoc, isBold: true),
                      _buildSpecRow('Hình thức:', order.hinhThucGiao),
                      _buildSpecRow('COD:', order.tienCod, isBold: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'TUYẾN ĐƯỜNG VẬN CHUYỂN (${order.quangDuongKm} KM)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Điểm lấy hàng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.diemLayHang,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'LH: ${order.lienHeLayHang}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: primaryRed, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Điểm giao hàng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.diemGiaoHang,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'LH: ${order.lienHeGiaoHang}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(
    String label,
    String value, {
    bool isBold = false,
    bool highlightValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: highlightValue ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _maxLoadPenaltyKm = 5.0;

  static const double _maxIdleBonusKm = 3.0;
  static const double _idleBonusFullMinutes = 60.0;

  double _loadRatio(ShipperModel shipper) {
    if (shipper.taiTrongToiDa <= 0) {
      return 1.0;
    }

    final ratio = shipper.taiTrongDangNhan / shipper.taiTrongToiDa;

    return ratio.clamp(0.0, 1.0);
  }

  double _idleBonusKm(ShipperModel shipper) {
    if (!shipper.dangRanh || shipper.ranhTu == null) {
      return 0.0;
    }

    final idleMinutes = shipper.idleDurationNow.inSeconds / 60.0;

    if (idleMinutes <= 0) {
      return 0.0;
    }

    final normalized = (idleMinutes / _idleBonusFullMinutes).clamp(0.0, 1.0);

    return normalized * _maxIdleBonusKm;
  }

  double _rankingScore(ShipperModel shipper) {
    final route = _shipperPickupRoutes[shipper.id];

    if (route == null) {
      return double.infinity;
    }

    final loadPenaltyKm = _loadRatio(shipper) * _maxLoadPenaltyKm;

    final idleBonusKm = _idleBonusKm(shipper);

    return route.distanceKm + loadPenaltyKm - idleBonusKm;
  }

  String _recommendationBadge(int rank) {
    if (rank == 0) return 'ĐỀ XUẤT #1';
    if (rank == 1) return 'ĐỀ XUẤT #2';
    if (rank == 2) return 'ĐỀ XUẤT #3';
    return '';
  }

  List<ShipperModel> _rankedShippersByDistance() {
    final ranked = List<ShipperModel>.from(_recommendedShippers);

    ranked.sort((a, b) {
      final aCanAssign = _canAssignSelectedOrderTo(a);
      final bCanAssign = _canAssignSelectedOrderTo(b);

      if (aCanAssign != bCanAssign) {
        return aCanAssign ? -1 : 1;
      }

      final aRoute = _shipperPickupRoutes[a.id];
      final bRoute = _shipperPickupRoutes[b.id];

      final aHasRoute = aRoute != null;
      final bHasRoute = bRoute != null;

      if (aHasRoute != bHasRoute) {
        return aHasRoute ? -1 : 1;
      }

      if (aRoute != null && bRoute != null) {
        final scoreCompare = _rankingScore(a).compareTo(_rankingScore(b));

        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final idleCompare = _idleBonusKm(b).compareTo(_idleBonusKm(a));

        if (idleCompare != 0) {
          return idleCompare;
        }

        final loadCompare = _loadRatio(a).compareTo(_loadRatio(b));

        if (loadCompare != 0) {
          return loadCompare;
        }

        final distanceCompare = aRoute.distanceKm.compareTo(bRoute.distanceKm);

        if (distanceCompare != 0) {
          return distanceCompare;
        }
      }

      return a.hoTen.toLowerCase().compareTo(b.hoTen.toLowerCase());
    });

    return _onlyAssignable
        ? ranked.where(_canAssignSelectedOrderTo).toList()
        : ranked;
  }

  Widget _buildShipperRecommendationsColumn() {
    final rankedShippers = _rankedShippersByDistance();
    final availableCount = rankedShippers.where((s) => s.isOnline).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Shipper đề xuất',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$availableCount ONLINE',
                style: TextStyle(fontSize: 10, color: Colors.green.shade700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune, size: 18),
              tooltip: _onlyAssignable
                  ? 'Hiển thị tất cả'
                  : 'Chỉ hiện tài xế đủ điều kiện',
              onPressed: () =>
                  setState(() => _onlyAssignable = !_onlyAssignable),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: rankedShippers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildShipperCard(rankedShippers[index], rank: index),
          ),
        ),
      ],
    );
  }

  Widget _buildShipperCard(ShipperModel shipper, {required int rank}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shipper.isOnline ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: rank == 0 && _canAssignSelectedOrderTo(shipper)
              ? primaryRed
              : const Color(0xFFCDD4CC),
          width: rank == 0 && _canAssignSelectedOrderTo(shipper) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rank < 3 && _canAssignSelectedOrderTo(shipper)) ...[
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rank == 0
                      ? Colors.amber.shade50
                      : primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: rank == 0
                        ? Colors.amber.shade700
                        : primaryRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rank == 0
                          ? Icons.workspace_premium_rounded
                          : Icons.auto_awesome_rounded,
                      size: 12,
                      color: rank == 0 ? Colors.amber.shade800 : primaryRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _recommendationBadge(rank),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: rank == 0 ? Colors.amber.shade900 : primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: shipper.isOnline
                    ? Colors.red.shade100
                    : Colors.grey.shade300,
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: shipper.isOnline ? primaryRed : Colors.grey,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipper.hoTen,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: shipper.isOnline ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'BS: ${shipper.bienSo}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (shipper.danhGia > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${shipper.danhGia} (${shipper.soDonDaGiao} đơn)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          if (shipper.isOnline)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KHOẢNG CÁCH TỚI ĐIỂM LẤY',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                        Text(
                          _formatRouteDistance(shipper),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TẢI HIỆN TẠI',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                        Text(
                          _capacityText(shipper),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _canAssignSelectedOrderTo(shipper)
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _capacitySubText(shipper),
                          style: TextStyle(
                            fontSize: 9,
                            color: _canAssignSelectedOrderTo(shipper)
                                ? Colors.grey.shade600
                                : Colors.orange.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else if (shipper.lyDoKhongKhaDung != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                shipper.lyDoKhongKhaDung!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _formatShipperIdleTime(shipper),
            style: TextStyle(fontSize: 11, color: _shipperIdleColor(shipper)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: shipper.isOnline
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: shipper.isOptimal
                          ? primaryRed
                          : Colors.white,
                      foregroundColor: shipper.isOptimal
                          ? Colors.white
                          : primaryRed,
                      side: shipper.isOptimal
                          ? BorderSide.none
                          : BorderSide(color: primaryRed),
                      elevation: 0,
                    ),
                    onPressed:
                        (_isAssigning || !_canAssignSelectedOrderTo(shipper))
                        ? null
                        : () => _assignOrderToShipper(shipper),
                    icon: Icon(
                      _canAssignSelectedOrderTo(shipper)
                          ? Icons.send_rounded
                          : Icons.warning_amber_rounded,
                      size: 14,
                    ),
                    label: Text(
                      _selectedOrder == null
                          ? 'Chưa chọn đơn'
                          : _canAssignSelectedOrderTo(shipper)
                          ? 'Chỉ định Shipper'
                          : 'Quá tải',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey.shade600,
                      elevation: 0,
                    ),
                    onPressed: null,
                    child: const Text(
                      'Không khả dụng',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
