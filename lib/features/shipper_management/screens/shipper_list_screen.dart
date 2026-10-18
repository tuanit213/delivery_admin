import 'package:admin/features/shipper_management/screens/approve_shipper_screen.dart';
import 'package:admin/models/shipper_model.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';

class ShipperListScreen extends StatefulWidget {
  const ShipperListScreen({super.key, this.initialSearch = ''});
  final String initialSearch;

  @override
  State<ShipperListScreen> createState() => _ShipperListScreenState();
}

class _ShipperListScreenState extends State<ShipperListScreen> {
  final Color primaryRed = const Color(0xFF245B69);
  List<ShipperModel> _shippers = [];
  bool _isLoading = true;
  String? _error;

  final Set<String> _disconnectingIds = <String>{};

  String _filterStatus = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearch;
    _searchController.text = widget.initialSearch;
    _fetchShippers();
  }

  @override
  void didUpdateWidget(covariant ShipperListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearch != widget.initialSearch) {
      _searchQuery = widget.initialSearch;
      _searchController.text = widget.initialSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShippers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<dynamic> raw = await ApiService.getDanhSachShipper();
      if (!mounted) return;

      setState(() {
        _shippers = raw
            .map((item) => ShipperModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _forceOfflineShipper(ShipperModel shipper) async {
    if (_disconnectingIds.contains(shipper.id)) return;

    final revision = ApiService.sessionRevision;
    _disconnectingIds.add(shipper.id);
    final bool hasActiveOrders =
        shipper.dangCoDonHoatDong || shipper.soDonDangXuLy > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ngắt kết nối Shipper?'),
          content: Text(
            hasActiveOrders
                ? '${shipper.hoTen} đang có ${shipper.soDonDangXuLy} đơn đang xử lý.\n\n'
                      'Ngắt kết nối chỉ chuyển Shipper sang Ngoại tuyến và ngừng nhận đơn mới. '
                      'Các đơn hiện có KHÔNG bị hủy hoặc tự chuyển cho tài xế khác.'
                : '${shipper.hoTen} sẽ được chuyển sang Ngoại tuyến và không nhận đơn mới.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Ngắt kết nối'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    _disconnectingIds.remove(shipper.id);
    if (confirmed != true ||
        !mounted ||
        revision != ApiService.sessionRevision) {
      return;
    }

    setState(() {
      _disconnectingIds.add(shipper.id);
    });

    try {
      final success = await ApiService.forceOffline(shipper.id);

      if (!mounted) return;

      if (!success) {
        throw Exception('Backend không chấp nhận thao tác ngắt kết nối.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển ${shipper.hoTen} sang Ngoại tuyến.'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      await _fetchShippers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể ngắt kết nối: '
            '${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _disconnectingIds.remove(shipper.id);
        });
      }
    }
  }

  Widget _buildPerformanceInfo(ShipperModel shipper) {
    final ratingText = shipper.hasRealRating
        ? '⭐ ${shipper.danhGia.toStringAsFixed(1)}'
        : 'Chưa có đánh giá';

    final deliveredText = '${shipper.soDonDaGiao} đơn đã giao';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          ratingText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: shipper.hasRealRating
                ? FontWeight.w600
                : FontWeight.normal,
            color: shipper.hasRealRating
                ? Colors.amber.shade800
                : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          deliveredText,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildApprovedActions(ShipperModel shipper) {
    final isDisconnecting = _disconnectingIds.contains(shipper.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPerformanceInfo(shipper),

        if (shipper.isOnline) ...[
          const SizedBox(width: 14),
          OutlinedButton.icon(
            onPressed: isDisconnecting
                ? null
                : () => _forceOfflineShipper(shipper),
            icon: isDisconnecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_off, size: 16),
            label: Text(isDisconnecting ? 'Đang ngắt...' : 'Ngắt kết nối'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredShippers = _shippers.where((s) {
      bool matchesStatus = true;
      if (_filterStatus == 'ChoDuyet') {
        matchesStatus = s.trangThaiDuyet == 'ChoDuyet';
      } else if (_filterStatus == 'TuChoi') {
        matchesStatus = s.trangThaiDuyet == 'TuChoi';
      } else if (_filterStatus == 'TrucTuyen') {
        matchesStatus = s.isOnline && s.trangThaiDuyet == 'DaDuyet';
      } else if (_filterStatus == 'NgoaiTuyen') {
        matchesStatus = !s.isOnline && s.trangThaiDuyet == 'DaDuyet';
      }

      final query = _searchQuery.toLowerCase().trim();
      bool matchesSearch =
          query.isEmpty ||
          s.hoTen.toLowerCase().contains(query) ||
          s.soDienThoai.toLowerCase().contains(query) ||
          s.bienSo.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();

    final int pendingCount = _shippers
        .where((s) => s.trangThaiDuyet == 'ChoDuyet')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(pendingCount),
            const SizedBox(height: 12),
            _buildSearchBarAndFilter(pendingCount),
            const SizedBox(height: 16),
            Expanded(child: _buildBodyList(filteredShippers)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int pendingCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản lý Đội ngũ Shipper',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Tổng số tài xế: ${_shippers.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      '$pendingCount hồ sơ chờ duyệt',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
          onPressed: _fetchShippers,
        ),
      ],
    );
  }

  Widget _buildSearchBarAndFilter(int pendingCount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, SĐT, biển số...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('Tất cả trạng thái'),
                ),
                DropdownMenuItem(
                  value: 'ChoDuyet',
                  child: Text('Chờ duyệt ($pendingCount)'),
                ),
                const DropdownMenuItem(
                  value: 'TrucTuyen',
                  child: Text('Đang Online'),
                ),
                const DropdownMenuItem(
                  value: 'NgoaiTuyen',
                  child: Text('Đang Offline'),
                ),
                const DropdownMenuItem(
                  value: 'TuChoi',
                  child: Text('Đã từ chối'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterStatus = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyList(List<ShipperModel> filteredShippers) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryRed));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: _fetchShippers,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (filteredShippers.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy tài xế nào',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredShippers.length,
      itemBuilder: (context, index) {
        return _buildShipperCard(filteredShippers[index]);
      },
    );
  }

  Widget _buildShipperCard(ShipperModel shipper) {
    final bool isPending = shipper.trangThaiDuyet == 'ChoDuyet';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarBgColor(shipper),
              child: Icon(Icons.person, color: _getAvatarIconColor(shipper)),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBadge(shipper),
                  const SizedBox(height: 6),
                  Text(
                    shipper.hoTen,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Biển số: ${shipper.bienSo} | SĐT: ${shipper.soDienThoai}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            if (isPending)
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ApproveShipperScreen(shipperId: shipper.id),
                    ),
                  );
                  if (mounted) await _fetchShippers();
                },
                icon: const Icon(Icons.rate_review, size: 16),
                label: const Text('Duyệt hồ sơ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              _buildApprovedActions(shipper),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ShipperModel shipper) {
    String label = '';
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;
    Color borderColor = Colors.grey.shade300;

    if (shipper.trangThaiDuyet == 'ChoDuyet') {
      label = 'CHỜ DUYỆT HỒ SƠ';
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      borderColor = Colors.orange.shade200;
    } else if (shipper.trangThaiDuyet == 'TuChoi') {
      label = 'ĐÃ TỪ CHỐI';
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      borderColor = Colors.red.shade200;
    } else {
      if (shipper.isOnline) {
        label = 'Đang trực tuyến';
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade200;
      } else {
        label = 'Đang ngoại tuyến';
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        borderColor = Colors.grey.shade300;
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Color _getAvatarBgColor(ShipperModel shipper) {
    if (shipper.trangThaiDuyet == 'ChoDuyet') return Colors.orange.shade100;
    if (shipper.trangThaiDuyet == 'TuChoi') return Colors.red.shade100;
    return shipper.isOnline ? Colors.green.shade100 : Colors.grey.shade300;
  }

  Color _getAvatarIconColor(ShipperModel shipper) {
    if (shipper.trangThaiDuyet == 'ChoDuyet') return Colors.orange.shade800;
    if (shipper.trangThaiDuyet == 'TuChoi') return Colors.red.shade800;
    return shipper.isOnline ? Colors.green.shade800 : Colors.grey.shade600;
  }
}
