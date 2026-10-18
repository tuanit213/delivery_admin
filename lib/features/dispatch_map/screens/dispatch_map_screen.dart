import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'package:admin/models/don_hang_model.dart';
import 'package:admin/models/shipper_model.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DispatchMapScreen extends StatefulWidget {
  const DispatchMapScreen({super.key});

  @override
  State<DispatchMapScreen> createState() => _DispatchMapScreenState();
}

class _DispatchMapScreenState extends State<DispatchMapScreen> {
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);
  static const Duration _refreshInterval = Duration(seconds: 15);

  List<Marker> _markers = [];
  List<Polyline> _routePolylines = [];
  List<Marker> _routeLabels = [];

  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshingSilently = false;
  bool _hasFittedInitialCamera = false;
  String? _error;

  int _orderCount = 0;
  int _onlineShipperCount = 0;

  int _ordersWithoutLocation = 0;
  int _onlineShippersWithoutLocation = 0;

  int _pickupMarkerCount = 0;
  int _deliveryMarkerCount = 0;
  int _shipperMarkerCount = 0;

  Map<String, List<DonHangModel>> _activeOrdersByShipperId = {};

  @override
  void initState() {
    super.initState();

    _loadMapDataFromApi();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isLoading && !_isRefreshingSilently) {
        _loadMapDataFromApi(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadMapDataFromApi({bool showLoading = true}) async {
    if (!mounted) return;

    setState(() {
      if (showLoading) {
        _isLoading = true;
      } else {
        _isRefreshingSilently = true;
      }

      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getDonHangDangHoatDong(),
        ApiService.getDanhSachShipper(),
      ]);

      if (!mounted) return;

      final rawOrders = results[0];
      final rawShippers = results[1];

      final orders = rawOrders
          .map(
            (item) =>
                DonHangModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
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
          .map(
            (item) =>
                ShipperModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      final activeShippers = shippers.where((shipper) {
        final isApproved =
            shipper.trangThaiDuyet.trim().toLowerCase() == 'daduyet';

        return isApproved && shipper.isOnline;
      }).toList();

      final shipperById = <String, ShipperModel>{
        for (final shipper in activeShippers) shipper.id: shipper,
      };

      final activeOrdersByShipperId = <String, List<DonHangModel>>{};

      for (final order in orders) {
        final maSp = order.maShipper;
        if (maSp == null || maSp.isEmpty) continue;

        activeOrdersByShipperId
            .putIfAbsent(maSp, () => <DonHangModel>[])
            .add(order);
      }

      final generatedMarkers = <Marker>[];
      final routePolylines = <Polyline>[];
      final routeLabels = <Marker>[];

      var ordersWithoutLocation = 0;
      var onlineShippersWithoutLocation = 0;

      var pickupMarkerCount = 0;
      var deliveryMarkerCount = 0;
      var shipperMarkerCount = 0;

      for (var index = 0; index < orders.length; index++) {
        final order = orders[index];
        final orderNumber = index + 1;
        var hasAtLeastOneLocation = false;

        if (order.hasValidPickupLocation) {
          hasAtLeastOneLocation = true;
          pickupMarkerCount++;

          generatedMarkers.add(
            _buildOrderMarker(
              order: order,
              orderNumber: orderNumber,
              markerType: 'L',
              locationType: 'Điểm lấy hàng',
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
          deliveryMarkerCount++;

          generatedMarkers.add(
            _buildOrderMarker(
              order: order,
              orderNumber: orderNumber,
              markerType: 'G',
              locationType: 'Điểm giao hàng',
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

            final midpoint = points[points.length ~/ 2];

            routeLabels.add(
              Marker(
                point: midpoint,
                width: 120,
                height: 36,
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
                      BoxShadow(color: Colors.black26, blurRadius: 4),
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

      for (final shipper in activeShippers) {
        if (!shipper.hasValidLocation) {
          onlineShippersWithoutLocation++;
          continue;
        }

        shipperMarkerCount++;

        final markerColor = shipper.isLocationStale
            ? Colors.amber
            : Colors.green;
        final gpsTime = _formatDateTime(shipper.locationUpdatedAt);

        generatedMarkers.add(
          Marker(
            point: LatLng(shipper.lat!, shipper.lng!),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Tooltip(
              message:
                  'Shipper: ${shipper.hoTen}\n'
                  'Biển số: ${shipper.bienSo}\n'
                  'GPS cập nhật: $gpsTime\n'
                  'Đơn active: ${activeOrdersByShipperId[shipper.id]?.map((o) => o.maDon).join(', ') ?? 'Không có'}',
              child: GestureDetector(
                onTap: () {
                  _showShipperDialog(shipper);
                },
                child: Icon(
                  Icons.directions_bike,
                  color: markerColor,
                  size: 36,
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

        _orderCount = orders.length;
        _onlineShipperCount = activeShippers.length;

        _ordersWithoutLocation = ordersWithoutLocation;
        _onlineShippersWithoutLocation = onlineShippersWithoutLocation;

        _pickupMarkerCount = pickupMarkerCount;
        _deliveryMarkerCount = deliveryMarkerCount;
        _shipperMarkerCount = shipperMarkerCount;

        _activeOrdersByShipperId = activeOrdersByShipperId;

        _isLoading = false;
        _isRefreshingSilently = false;
      });

      if (!_hasFittedInitialCamera && generatedMarkers.isNotEmpty) {
        _hasFittedInitialCamera = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _fitMapToMarkers();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isRefreshingSilently = false;
      });
    }
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _markers.map((marker) => marker.point).toList(),
        padding: const EdgeInsets.fromLTRB(60, 130, 60, 130),
        maxZoom: 16,
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có dữ liệu';
    }

    final local = value.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  Marker _buildOrderMarker({
    required DonHangModel order,
    required int orderNumber,
    required String markerType,
    required String locationType,
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
        'Loại điểm: $locationType\n'
        'Địa chỉ: $address\n'
        'Điểm lấy: ${order.diemLayHang}\n'
        'Điểm giao: ${order.diemGiaoHang}\n'
        'Người nhận: ${order.tenNguoiNhan}\n'
        'Liên hệ: ${order.lienHeGiaoHang}\n'
        'Khối lượng: ${order.trongLuong} kg\n'
        'COD: ${order.tienCod}\n'
        'Trạng thái: ${order.trangThai}\n'
        'Shipper: ${assignedShipperLabel ?? 'Chưa phân'}\n'
        'Ngày tạo: ${_formatDateTime(order.ngayTao)}';

    return Marker(
      point: point,
      width: 160,
      height: assignedShipper == null ? 66 : 82,
      alignment: Alignment.bottomCenter,
      child: Tooltip(
        waitDuration: const Duration(milliseconds: 250),
        showDuration: const Duration(seconds: 8),
        message: tooltipMessage,
        child: GestureDetector(
          onTap: () {
            _showOrderDialog(
              order: order,
              orderNumber: orderNumber,
              locationType: locationType,
              address: address,
              assignedShipper: assignedShipper,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 156),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: color, width: 1.4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
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
                  constraints: const BoxConstraints(maxWidth: 156),
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
              Icon(Icons.location_on, color: color, size: 34),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDialog({
    required DonHangModel order,
    required int orderNumber,
    required String locationType,
    required String address,
    ShipperModel? assignedShipper,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Đơn #$orderNumber — ${order.maDon}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Loại điểm: $locationType\n'
            'Địa chỉ: $address\n\n'
            'Điểm lấy: ${order.diemLayHang}\n'
            'Điểm giao: ${order.diemGiaoHang}\n'
            'Người nhận: ${order.tenNguoiNhan}\n'
            'Liên hệ: ${order.lienHeGiaoHang}\n'
            'Trạng thái: ${order.trangThai}\n'
            'Shipper: ${assignedShipper == null ? 'Chưa phân' : '${assignedShipper.hoTen} (${assignedShipper.id})'}',
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

  void _showShipperDialog(ShipperModel shipper) {
    final updatedAtText = _formatDateTime(shipper.locationUpdatedAt);
    final assignedOrders =
        _activeOrdersByShipperId[shipper.id] ?? const <DonHangModel>[];

    final assignedOrderText = assignedOrders.isEmpty
        ? 'Không có đơn active'
        : assignedOrders.map((order) => order.maDon).join(', ');
    final gpsStatus = shipper.isLocationStale
        ? 'Dữ liệu GPS đã cũ'
        : 'GPS đang cập nhật';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Shipper: ${shipper.hoTen}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Mã shipper: ${shipper.id}\n'
            'Biển số: ${shipper.bienSo}\n'
            'Số điện thoại: ${shipper.soDienThoai}\n'
            'Trạng thái: Online\n'
            'GPS: $gpsStatus\n'
            'Cập nhật cuối: $updatedAtText\n'
            'Đơn đang phụ trách (${assignedOrders.length}): $assignedOrderText',
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

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _loadMapDataFromApi(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 13.5,
      ),
      children: [
        TileLayer(
          urlTemplate: const String.fromEnvironment(
            'MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
          ),
          userAgentPackageName: 'com.admin.lougiroute',
        ),
        SimpleAttributionWidget(
          alignment: Alignment.topRight,
          source: const Text('OpenStreetMap contributors'),
          onTap: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        ),
        if (_routePolylines.isNotEmpty)
          PolylineLayer(polylines: _routePolylines),
        if (_routeLabels.isNotEmpty) MarkerLayer(markers: _routeLabels),
        MarkerLayer(markers: _markers),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapContent()),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map, color: Color(0xFF245B69)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bản đồ điều phối '
                          '(${_markers.length} vị trí hợp lệ)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isRefreshingSilently)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong),
                        tooltip: 'Xem tất cả vị trí',
                        onPressed: _markers.isEmpty ? null : _fitMapToMarkers,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Tải lại bản đồ',
                        onPressed: _isLoading
                            ? null
                            : () => _loadMapDataFromApi(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (!_isLoading && _error == null && _markers.isEmpty)
            Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 42,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chưa có dữ liệu vị trí hợp lệ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_ordersWithoutLocation đơn thiếu tọa độ\n'
                        '$_onlineShippersWithoutLocation shipper online thiếu GPS',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_isLoading && _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Đơn: $_orderCount',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('Điểm lấy: $_pickupMarkerCount'),
                        Text('Điểm giao: $_deliveryMarkerCount'),
                        Text('Shipper online: $_onlineShipperCount'),
                        Text('Có GPS: $_shipperMarkerCount'),
                        Text(
                          'Đơn thiếu tọa độ: $_ordersWithoutLocation',
                          style: TextStyle(
                            color: _ordersWithoutLocation > 0
                                ? Colors.red
                                : null,
                          ),
                        ),
                        Text(
                          'Online thiếu GPS: '
                          '$_onlineShippersWithoutLocation',
                          style: TextStyle(
                            color: _onlineShippersWithoutLocation > 0
                                ? Colors.red
                                : null,
                          ),
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bike,
                              size: 18,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text('GPS mới'),
                          ],
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bike,
                              size: 18,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 4),
                            Text('GPS quá 5 phút'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
