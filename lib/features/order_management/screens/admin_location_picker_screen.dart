import 'package:url_launcher/url_launcher.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminLocationPickerScreen extends StatefulWidget {
  const AdminLocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
    this.routeStartLocation,
  });

  final String title;
  final LatLng? initialLocation;
  final LatLng? routeStartLocation;

  @override
  State<AdminLocationPickerScreen> createState() =>
      _AdminLocationPickerScreenState();
}

class _AdminLocationPickerScreenState extends State<AdminLocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);

  late LatLng selectedLocation;
  ShippingRouteData? _routePreview;
  bool _loadingRoute = false;
  int _routeRequestId = 0;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation ?? _defaultCenter;

    if (widget.routeStartLocation != null && widget.initialLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRoutePreview(selectedLocation);
      });
    }
  }

  Future<void> _loadRoutePreview(LatLng destination) async {
    if (!mounted) return;
    final start = widget.routeStartLocation;
    if (start == null) return;

    final requestId = ++_routeRequestId;
    setState(() => _loadingRoute = true);

    try {
      final result = await ApiService.getShippingRoute(
        pickupLat: start.latitude,
        pickupLng: start.longitude,
        deliveryLat: destination.latitude,
        deliveryLng: destination.longitude,
      );

      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _routePreview = result;
        _loadingRoute = false;
      });
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _routePreview = null;
        _loadingRoute = false;
      });
    }
  }

  void _confirm() {
    if (_confirmed || !mounted) return;
    _confirmed = true;
    Navigator.of(context).pop(selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final routePoints =
        _routePreview?.routePoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList() ??
        <LatLng>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Xác nhận')),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: selectedLocation,
              initialZoom: 15,
              onTap: (_, point) {
                setState(() => selectedLocation = point);
                _loadRoutePreview(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: const String.fromEnvironment(
                  'MAP_TILE_URL',
                  defaultValue: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                ),
                userAgentPackageName: 'com.logiroute.admin',
              ),
              SimpleAttributionWidget(
                alignment: Alignment.topRight,
                source: const Text('OpenStreetMap contributors'),
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
              ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.routeStartLocation != null)
                    Marker(
                      point: widget.routeStartLocation!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.inventory_2,
                        size: 38,
                        color: Colors.green,
                      ),
                    ),
                  Marker(
                    point: selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                elevation: 4,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Chạm vào bản đồ để đặt ghim đúng vị trí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadingRoute
                              ? 'Đang tính tuyến đường bộ...'
                              : _routePreview != null
                              ? 'Quãng đường: ${_routePreview!.distanceKm.toStringAsFixed(2)} km\n'
                                    'Dự kiến: ${_routePreview!.durationMinutes} phút'
                              : 'Vĩ độ: ${selectedLocation.latitude.toStringAsFixed(6)}\n'
                                    'Kinh độ: ${selectedLocation.longitude.toStringAsFixed(6)}',
                        ),
                      ),
                      FilledButton(
                        onPressed: _confirm,
                        child: const Text('Dùng vị trí này'),
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
