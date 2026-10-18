import 'package:admin/features/order_management/screens/admin_location_picker_screen.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';

class AdminCreateOrderScreen extends StatefulWidget {
  const AdminCreateOrderScreen({super.key, this.editOrderId});

  final String? editOrderId;

  @override
  State<AdminCreateOrderScreen> createState() => _AdminCreateOrderScreenState();
}

class _AdminCreateOrderScreenState extends State<AdminCreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final senderName = TextEditingController();
  final senderPhone = TextEditingController();
  final receiverName = TextEditingController();
  final receiverPhone = TextEditingController();
  final weight = TextEditingController();
  final cod = TextEditingController(text: '0');
  final size = TextEditingController();
  final pickupAddress = TextEditingController();
  final deliveryAddress = TextEditingController();

  LatLng? pickupLocation;
  LatLng? deliveryLocation;
  ShippingRouteData? _shippingRoute;
  String? _customerId;

  bool resolvingPickupAddress = false;
  bool resolvingDeliveryAddress = false;
  bool calculatingShippingFee = false;
  bool submitting = false;
  bool loadingEditData = false;
  bool _pickingLocation = false;
  int _quoteRequestId = 0;

  bool get isEditMode =>
      widget.editOrderId != null && widget.editOrderId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderForEdit();
      });
    }
  }

  Future<void> _loadOrderForEdit() async {
    if (!mounted || !isEditMode || loadingEditData) return;

    setState(() => loadingEditData = true);

    try {
      final data = await ApiService.getChiTietDonHang(
        widget.editOrderId!.trim(),
      );
      if (!mounted) return;

      final trangThai = data['trangThai']?.toString() ?? '';
      final maSp = data['maSp']?.toString().trim();

      if (trangThai != 'ChoXacNhan' || (maSp != null && maSp.isNotEmpty)) {
        throw Exception(
          'Chỉ được chỉnh sửa đơn đang Chờ xác nhận '
          'và chưa được phân Shipper.',
        );
      }

      final pickupLat = _toDouble(data['viDoLay']);
      final pickupLng = _toDouble(data['kinhDoLay']);
      final deliveryLat = _toDouble(data['viDoGiao']);
      final deliveryLng = _toDouble(data['kinhDoGiao']);

      if (pickupLat == null ||
          pickupLng == null ||
          deliveryLat == null ||
          deliveryLng == null) {
        throw Exception(
          'Đơn hàng thiếu tọa độ lấy/giao nên chưa thể chỉnh sửa.',
        );
      }

      senderName.text = data['tenNguoiGui']?.toString() ?? '';
      _customerId = data['maKh']?.toString();
      senderPhone.text = data['sdtNguoiGui']?.toString() ?? '';
      receiverName.text = data['tenNguoiNhan']?.toString() ?? '';
      receiverPhone.text = data['sdtNguoiNhan']?.toString() ?? '';
      weight.text = _numberText(data['khoiLuong']);
      cod.text = _numberText(data['tienCod'], fallback: '0');
      size.text = data['kichThuoc']?.toString() ?? '';
      pickupAddress.text = data['diaChiLay']?.toString() ?? '';
      deliveryAddress.text = data['diaChiGiao']?.toString() ?? '';

      pickupLocation = LatLng(pickupLat, pickupLng);
      deliveryLocation = LatLng(deliveryLat, deliveryLng);

      if (mounted) {
        setState(() {});
      }

      await _refreshShippingQuote();
    } catch (error) {
      if (!mounted) return;

      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => loadingEditData = false);
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _numberText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final parsed = _toDouble(value);
    if (parsed == null) return value.toString();

    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toString();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    } else {
      context.go('/order_management');
    }
  }

  @override
  void dispose() {
    for (final controller in [
      senderName,
      senderPhone,
      receiverName,
      receiverPhone,
      weight,
      cod,
      size,
      pickupAddress,
      deliveryAddress,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation({required bool isPickup}) async {
    if (!mounted || submitting || loadingEditData || _pickingLocation) return;
    setState(() => _pickingLocation = true);
    try {
      final result = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) => AdminLocationPickerScreen(
            title: isPickup ? 'Chọn vị trí lấy hàng' : 'Chọn vị trí giao hàng',
            initialLocation: isPickup ? pickupLocation : deliveryLocation,
            routeStartLocation: isPickup ? null : pickupLocation,
          ),
        ),
      );

      if (!mounted || result == null) return;

      setState(() {
        if (isPickup) {
          resolvingPickupAddress = true;
        } else {
          resolvingDeliveryAddress = true;
        }
      });

      try {
        final address = await geocodingService.reverseGeocode(result);

        if (!mounted) return;

        setState(() {
          if (isPickup) {
            pickupLocation = result;
            pickupAddress.text = address;
          } else {
            deliveryLocation = result;
            deliveryAddress.text = address;
          }
        });

        await _refreshShippingQuote();
      } catch (error) {
        if (mounted) _showError(error.toString());
      } finally {
        if (mounted) {
          setState(() {
            if (isPickup) {
              resolvingPickupAddress = false;
            } else {
              resolvingDeliveryAddress = false;
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => _pickingLocation = false);
    }
  }

  Future<void> _refreshShippingQuote() async {
    if (!mounted) return;
    final requestId = ++_quoteRequestId;
    final pickup = pickupLocation;
    final delivery = deliveryLocation;

    if (pickup == null || delivery == null) {
      if (mounted) setState(() => _shippingRoute = null);
      return;
    }

    setState(() {
      calculatingShippingFee = true;
      _shippingRoute = null;
    });

    try {
      final route = await ApiService.getShippingRoute(
        pickupLat: pickup.latitude,
        pickupLng: pickup.longitude,
        deliveryLat: delivery.latitude,
        deliveryLng: delivery.longitude,
        customerId: _customerId,
      );

      if (!mounted || requestId != _quoteRequestId) return;
      setState(() => _shippingRoute = route);
    } catch (error) {
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() => _shippingRoute = null);
      _showError('Không thể tính phí vận chuyển: $error');
    } finally {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => calculatingShippingFee = false);
      }
    }
  }

  Future<void> _submit() async {
    if (submitting ||
        _pickingLocation ||
        loadingEditData ||
        resolvingPickupAddress ||
        resolvingDeliveryAddress ||
        calculatingShippingFee) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final pickup = pickupLocation;
    final delivery = deliveryLocation;

    if (pickup == null ||
        delivery == null ||
        pickupAddress.text.trim().isEmpty ||
        deliveryAddress.text.trim().isEmpty) {
      _showError('Vui lòng chọn đầy đủ điểm lấy và điểm giao.');
      return;
    }

    if (_shippingRoute == null) {
      _showError('Chưa tính được tuyến đường và phí vận chuyển.');
      return;
    }

    final weightValue = double.tryParse(weight.text.trim());
    final codValue = double.tryParse(cod.text.trim());

    if (weightValue == null || weightValue <= 0) {
      _showError('Khối lượng phải lớn hơn 0.');
      return;
    }

    if (codValue == null || codValue < 0) {
      _showError('Tiền COD không hợp lệ.');
      return;
    }

    setState(() => submitting = true);

    try {
      final payload = <String, dynamic>{
        'senderName': senderName.text.trim(),
        'senderPhone': senderPhone.text.trim(),
        'receiverName': receiverName.text.trim(),
        'receiverPhone': receiverPhone.text.trim(),
        'pickupAddress': pickupAddress.text.trim(),
        'deliveryAddress': deliveryAddress.text.trim(),
        'weightKg': weightValue,
        'kichThuoc': size.text.trim().isEmpty ? null : size.text.trim(),
        'codAmount': codValue,
        'viDoLay': pickup.latitude,
        'kinhDoLay': pickup.longitude,
        'viDoGiao': delivery.latitude,
        'kinhDoGiao': delivery.longitude,
      };

      final Map<String, dynamic> response;

      if (isEditMode) {
        response = await ApiService.adminCapNhatDon(
          widget.editOrderId!,
          payload,
        );
      } else {
        response = await ApiService.adminTaoDon({
          'customerId': null,
          ...payload,
        });
      }

      if (!mounted) return;

      final orderCode =
          (response['maDh'] ?? response['maDonHang'])?.toString() ??
          widget.editOrderId;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Cập nhật đơn thành công: $orderCode'
                : orderCode == null
                ? 'Tạo đơn thành công.'
                : 'Tạo đơn thành công: $orderCode',
          ),
        ),
      );

      if (isEditMode) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/order_management');
      }
    } catch (error) {
      if (mounted) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatMoney(double value) {
    final text = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} đ';
  }

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool phone = false,
    bool number = false,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: phone
            ? TextInputType.phone
            : number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]
            : null,
        decoration: _decoration(label, hint: hint, icon: icon),
        validator: validator,
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _locationSelector({
    required String label,
    required LatLng? location,
    required String address,
    required bool resolving,
    required VoidCallback onTap,
  }) {
    final selected = location != null && address.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? Colors.green.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: selected ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.location_on : Icons.location_off,
            color: selected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: resolving
                ? const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Đang xác định địa chỉ...'),
                    ],
                  )
                : Text(
                    selected ? '$label\n$address' : '$label chưa được chọn',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed:
                resolving || submitting || loadingEditData || _pickingLocation
                ? null
                : onTap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(selected ? 'Chọn lại' : 'Chọn trên bản đồ'),
          ),
        ],
      ),
    );
  }

  Widget _readonlyAddress(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        maxLines: 3,
        decoration: _decoration(
          label,
          hint: 'Địa chỉ tự điền sau khi chọn vị trí',
          icon: Icons.place_outlined,
        ),
      ),
    );
  }

  Widget _shippingSummary() {
    if (calculatingShippingFee) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Đang tính tuyến đường và phí...'),
          ],
        ),
      );
    }

    final route = _shippingRoute;

    if (route == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text('Chọn đủ điểm lấy và giao để hệ thống tự tính phí.'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 10,
        children: [
          Text(
            'Phí vận chuyển: ${_formatMoney(route.shippingFee)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text('Quãng đường: ${route.distanceKm.toStringAsFixed(2)} km'),
          Text('Dự kiến: ${route.durationMinutes} phút'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E5),
      body: loadingEditData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Quay lại',
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditMode ? 'Chỉnh sửa đơn hàng' : 'Tạo đơn mới',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEditMode
                                  ? 'Cập nhật thông tin đơn chưa phân công'
                                  : 'Tạo đơn hộ khách vãng lai',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _section('Thông tin người gửi', [
                    _field(
                      controller: senderName,
                      label: 'Tên người gửi',
                      hint: 'VD: Nguyễn Văn A',
                      icon: Icons.person_outline,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Vui lòng nhập tên người gửi'
                          : null,
                    ),
                    _field(
                      controller: senderPhone,
                      label: 'Số điện thoại người gửi',
                      phone: true,
                      icon: Icons.phone_outlined,
                      validator: (value) => (value ?? '').trim().length != 10
                          ? 'Số điện thoại phải có 10 chữ số'
                          : null,
                    ),
                  ]),

                  _section('Thông tin kiện hàng', [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: weight,
                            label: 'Khối lượng (kg)',
                            hint: 'VD: 2.5',
                            number: true,
                            icon: Icons.scale_outlined,
                            validator: (value) {
                              final number = double.tryParse(
                                value?.trim() ?? '',
                              );
                              return number == null || number <= 0
                                  ? 'Khối lượng không hợp lệ'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _field(
                            controller: size,
                            label: 'Kích thước',
                            hint: 'VD: 30x20x15',
                            icon: Icons.straighten_outlined,
                          ),
                        ),
                      ],
                    ),
                    _field(
                      controller: cod,
                      label: 'Tiền COD (VNĐ)',
                      hint: '0 nếu không thu hộ',
                      number: true,
                      icon: Icons.payments_outlined,
                      validator: (value) {
                        final number = double.tryParse(value?.trim() ?? '');
                        return number == null || number < 0
                            ? 'Tiền COD không hợp lệ'
                            : null;
                      },
                    ),
                    _shippingSummary(),
                  ]),

                  _section('Lộ trình', [
                    _locationSelector(
                      label: 'Vị trí lấy hàng',
                      location: pickupLocation,
                      address: pickupAddress.text,
                      resolving: resolvingPickupAddress,
                      onTap: () => _pickLocation(isPickup: true),
                    ),
                    _readonlyAddress('Địa chỉ lấy hàng', pickupAddress),
                    _locationSelector(
                      label: 'Vị trí giao hàng',
                      location: deliveryLocation,
                      address: deliveryAddress.text,
                      resolving: resolvingDeliveryAddress,
                      onTap: () => _pickLocation(isPickup: false),
                    ),
                    _readonlyAddress('Địa chỉ giao hàng', deliveryAddress),
                  ]),

                  _section('Thông tin người nhận', [
                    _field(
                      controller: receiverName,
                      label: 'Tên người nhận',
                      icon: Icons.person_outline,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Vui lòng nhập tên người nhận'
                          : null,
                    ),
                    _field(
                      controller: receiverPhone,
                      label: 'Số điện thoại người nhận',
                      phone: true,
                      icon: Icons.phone_outlined,
                      validator: (value) => (value ?? '').trim().length != 10
                          ? 'Số điện thoại phải có 10 chữ số'
                          : null,
                    ),
                  ]),

                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF245B69),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_task),
                        label: Text(
                          submitting
                              ? (isEditMode ? 'Đang lưu...' : 'Đang tạo đơn...')
                              : (isEditMode ? 'Lưu thay đổi' : 'Tạo đơn hàng'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
