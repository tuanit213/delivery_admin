import 'package:url_launcher/url_launcher.dart';
import 'package:admin/models/don_hang_model.dart';
import 'package:admin/models/shipper_model.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;

  List<Marker> _markers = [];
  List<Polyline> _routePolylines = [];
  List<Marker> _routeLabels = [];

  Map<String, List<DonHangModel>> _activeOrdersByShipperId = {};

  int _pendingOrdersCount = 0;
  int _onlineShippersCount = 0;
  int _shippingOrdersCount = 0;
  int _codWarningsCount = 0;

  int _ordersWithoutLocation = 0;
  int _shippersWithoutLocation = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getDonHangChoNhan(),

        ApiService.getDonHangDangHoatDong(),

        ApiService.getDanhSachShipper(),
        ApiService.getSoLuongDangGiao(),
        ApiService.getSoLuongCanhBaoCod(),
      ]);

      if (!mounted) return;

      final rawPendingOrders = results[0] as List<dynamic>;
      final rawActiveOrders = results[1] as List<dynamic>;
      final rawShippers = results[2] as List<dynamic>;

      final orders = rawActiveOrders
          .whereType<Map<String, dynamic>>()
          .map(DonHangModel.fromJson)
          .toList();

      orders.sort((a, b) {
        final aDate = a.ngayTao;
        final bDate = b.ngayTao;

        if (aDate == null && bDate == null) {
          return a.maDon.compareTo(b.maDon);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        final byDate = aDate.compareTo(bDate);
        return byDate != 0 ? byDate : a.maDon.compareTo(b.maDon);
      });

      final shippers = rawShippers
          .whereType<Map<String, dynamic>>()
          .map(ShipperModel.fromJson)
          .toList();

      final shippingCount = results[3] is int ? results[3] as int : 0;
      final codWarningCount = results[4] is int ? results[4] as int : 0;

      final shipperById = <String, ShipperModel>{
        for (final shipper in shippers) shipper.id: shipper,
      };

      final activeOrdersByShipperId = <String, List<DonHangModel>>{};

      for (final order in orders) {
        final maSp = order.maShipper;

        if (maSp == null || maSp.isEmpty) {
          continue;
        }

        activeOrdersByShipperId
            .putIfAbsent(maSp, () => <DonHangModel>[])
            .add(order);
      }

      final generatedMarkers = <Marker>[];
      final routePolylines = <Polyline>[];
      final routeLabels = <Marker>[];

      var ordersWithoutLocation = 0;
      var shippersWithoutLocation = 0;

      for (var index = 0; index < orders.length; index++) {
        final order = orders[index];
        final orderNumber = index + 1;
        var hasAtLeastOneLocation = false;

        if (order.hasValidPickupLocation) {
          hasAtLeastOneLocation = true;

          generatedMarkers.add(
            _buildOrderMarker(
              order: order,
              orderNumber: orderNumber,
              markerType: 'L',
              locationName: 'Điểm lấy hàng',
              address: order.diemLayHang,
              point: LatLng(order.pickupLatitude!, order.pickupLongitude!),
              color: Colors.orange,
              icon: Icons.inventory_2,
              assignedShipper: order.maShipper == null
                  ? null
                  : shipperById[order.maShipper],
            ),
          );
        }

        if (order.hasValidDeliveryLocation) {
          hasAtLeastOneLocation = true;

          generatedMarkers.add(
            _buildOrderMarker(
              order: order,
              orderNumber: orderNumber,
              markerType: 'G',
              locationName: 'Điểm giao hàng',
              address: order.diemGiaoHang,
              point: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
              color: Colors.red,
              icon: Icons.flag,
              assignedShipper: order.maShipper == null
                  ? null
                  : shipperById[order.maShipper],
            ),
          );
        }

        if (!hasAtLeastOneLocation) {
          ordersWithoutLocation++;
        }
      }

      for (var index = 0; index < orders.length; index++) {
        final order = orders[index];

        if (!order.hasValidPickupLocation || !order.hasValidDeliveryLocation) {
          continue;
        }

        try {
          final route = await ApiService.getShippingRoute(
            pickupLat: order.pickupLatitude!,
            pickupLng: order.pickupLongitude!,
            deliveryLat: order.deliveryLatitude!,
            deliveryLng: order.deliveryLongitude!,
          );

          final points = route.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

          if (points.length >= 2) {
            routePolylines.add(
              Polyline(
                points: points,
                strokeWidth: 4,
                color: Colors.blueAccent,
              ),
            );

            final mid = points[points.length ~/ 2];

            routeLabels.add(
              Marker(
                point: mid,
                width: 110,
                height: 34,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: Text(
                    '#${index + 1} • '
                    '${route.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }
        } catch (_) {}
      }

      for (final shipper in shippers) {
        if (!shipper.hasValidLocation) {
          shippersWithoutLocation++;
          continue;
        }

        final Color markerColor;

        if (!shipper.isOnline) {
          markerColor = Colors.grey;
        } else if (shipper.isLocationStale) {
          markerColor = Colors.amber;
        } else {
          markerColor = Colors.green;
        }

        generatedMarkers.add(
          Marker(
            point: LatLng(shipper.lat!, shipper.lng!),
            width: 42,
            height: 42,
            child: Tooltip(
              waitDuration: const Duration(milliseconds: 250),
              message:
                  'Shipper: ${shipper.hoTen}\n'
                  'Mã: ${shipper.id}\n'
                  'Biển số: ${shipper.bienSo}\n'
                  'Trạng thái: ${shipper.isOnline ? "Online" : "Offline"}\n'
                  'GPS: ${shipper.locationUpdatedAt?.toLocal() ?? "Chưa có"}\n'
                  'Đơn active: ${activeOrdersByShipperId[shipper.id]?.map((o) => o.maDon).join(', ') ?? 'Không có'}',
              child: GestureDetector(
                onTap: () {
                  _showShipperActionSheet(shipper);
                },
                child: Icon(
                  Icons.directions_bike,
                  color: markerColor,
                  size: 34,
                ),
              ),
            ),
          ),
        );
      }

      setState(() {
        _markers = generatedMarkers;
        _routePolylines = routePolylines;
        _routeLabels = routeLabels;

        _activeOrdersByShipperId = activeOrdersByShipperId;

        _pendingOrdersCount = rawPendingOrders.length;

        _onlineShippersCount = shippers
            .where((shipper) => shipper.isOnline)
            .length;

        _shippingOrdersCount = shippingCount;
        _codWarningsCount = codWarningCount;
        _ordersWithoutLocation = ordersWithoutLocation;
        _shippersWithoutLocation = shippersWithoutLocation;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Marker _buildOrderMarker({
    required DonHangModel order,
    required int orderNumber,
    required String markerType,
    required String locationName,
    required String address,
    required LatLng point,
    required Color color,
    required IconData icon,
    ShipperModel? assignedShipper,
  }) {
    final shortLabel = '$markerType$orderNumber • ${order.maDon}';
    final assignedShipperLabel = assignedShipper == null
        ? null
        : '${assignedShipper.hoTen} • ${assignedShipper.bienSo}';

    final tooltipMessage =
        'Đơn #$orderNumber — ${order.maDon}\n'
        'Loại điểm: $locationName\n'
        'Địa chỉ: $address\n'
        'Người nhận: ${order.tenNguoiNhan}\n'
        'Liên hệ: ${order.lienHeGiaoHang}\n'
        'Khối lượng: ${order.trongLuong} kg\n'
        'COD: ${order.tienCod}\n'
        'Trạng thái: ${order.trangThai}\n'
        'Shipper: ${assignedShipperLabel ?? 'Chưa phân'}\n'
        'Ngày tạo: ${order.ngayTao?.toLocal() ?? "Không rõ"}';

    return Marker(
      point: point,
      width: 150,
      height: assignedShipper == null ? 58 : 82,
      alignment: Alignment.topCenter,
      child: Tooltip(
        waitDuration: const Duration(milliseconds: 250),
        showDuration: const Duration(seconds: 8),
        message: tooltipMessage,
        child: GestureDetector(
          onTap: () {
            _showOrderDialog(
              order: order,
              orderNumber: orderNumber,
              locationName: locationName,
              address: address,
              assignedShipper: assignedShipper,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 148),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 4,
                      offset: Offset(0, 2),
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (assignedShipper != null)
                Container(
                  constraints: const BoxConstraints(maxWidth: 148),
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_bike,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          assignedShipper.hoTen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Icon(Icons.location_on, color: color, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDialog({
    required DonHangModel order,
    required int orderNumber,
    required String locationName,
    required String address,
    ShipperModel? assignedShipper,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Đơn #$orderNumber — ${order.maDon}'),
          content: Text(
            'Loại điểm: $locationName\n'
            'Địa chỉ hiện tại: $address\n\n'
            'Điểm lấy: ${order.diemLayHang}\n'
            'Điểm giao: ${order.diemGiaoHang}\n'
            'Người nhận: ${order.tenNguoiNhan}\n'
            'Liên hệ: ${order.lienHeGiaoHang}\n'
            'Khối lượng: ${order.trongLuong} kg\n'
            'COD: ${order.tienCod}\n'
            'Trạng thái: ${order.trangThai}\n'
            'Shipper: ${assignedShipper == null ? 'Chưa phân' : '${assignedShipper.hoTen} (${assignedShipper.id})'}\n'
            'Ngày tạo: ${order.ngayTao?.toLocal() ?? "Không rõ"}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _showShipperActionSheet(ShipperModel shipper) {
    final updatedAtText =
        shipper.locationUpdatedAt?.toLocal().toString() ??
        'Chưa có dữ liệu GPS';

    final assignedOrders =
        _activeOrdersByShipperId[shipper.id] ?? const <DonHangModel>[];

    final assignedOrderText = assignedOrders.isEmpty
        ? 'Không có đơn active'
        : assignedOrders.map((order) => order.maDon).join(', ');

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipper: ${shipper.hoTen}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Mã: ${shipper.id}'),
                Text('Biển số: ${shipper.bienSo}'),
                Text(
                  'Trạng thái: '
                  '${shipper.isOnline ? "Online" : "Offline"}',
                ),
                Text('GPS cập nhật: $updatedAtText'),
                Text(
                  'Đơn đang phụ trách (${assignedOrders.length}): '
                  '$assignedOrderText',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Đã xảy ra lỗi:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Quản Lý'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: 'Tải lại dữ liệu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorContent()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Đơn chờ',
                        '$_pendingOrdersCount',
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Đang giao',
                        '$_shippingOrdersCount',
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Tài xế Online',
                        '$_onlineShippersCount',
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Cảnh báo COD',
                        '$_codWarningsCount',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
                if (_ordersWithoutLocation > 0 || _shippersWithoutLocation > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Dữ liệu bản đồ chưa đầy đủ: '
                      '$_ordersWithoutLocation đơn thiếu tọa độ, '
                      '$_shippersWithoutLocation shipper thiếu GPS.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(10.7769, 106.7009),
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: const String.fromEnvironment(
                          'MAP_TILE_URL',
                          defaultValue:
                              'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                        ),
                        userAgentPackageName: 'com.admin.lougiroute',
                      ),
                      SimpleAttributionWidget(
                        alignment: Alignment.topRight,
                        source: const Text('OpenStreetMap contributors'),
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                      if (_routePolylines.isNotEmpty)
                        PolylineLayer(polylines: _routePolylines),
                      if (_routeLabels.isNotEmpty)
                        MarkerLayer(markers: _routeLabels),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
