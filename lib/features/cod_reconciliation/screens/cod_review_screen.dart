import 'package:admin/models/cod_model.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodReviewScreen extends StatefulWidget {
  const CodReviewScreen({super.key});

  @override
  State<CodReviewScreen> createState() => _CodReviewScreenState();
}

class _CodReviewScreenState extends State<CodReviewScreen> {
  static const Color _primaryRed = Color(0xFF245B69);

  List<CodModel> _codList = [];
  bool _isLoading = true;
  bool _isApproving = false;
  bool _confirming = false;
  String? _error;
  String? _adminMaTk;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final maTk = prefs.getString('admin_ma_tk');

    if (!mounted) return;

    setState(() => _adminMaTk = maTk);
    await _fetchCodData();
  }

  Future<void> _fetchCodData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getDanhSachPhieuChoDuyet();

      final list = data
          .whereType<Map>()
          .map((item) => CodModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      list.sort((a, b) {
        final aDate = a.ngayDoiSoat;
        final bDate = b.ngayDoiSoat;

        if (aDate == null && bDate == null) {
          return a.maDs.compareTo(b.maDs);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _codList = list;
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

  Future<void> _confirmApprove(CodModel item) async {
    if (!mounted || _isApproving || _confirming) return;
    final revision = ApiService.sessionRevision;
    final adminMaTk = _adminMaTk;

    if (adminMaTk == null || adminMaTk.isEmpty) {
      _showMessage(
        'Không tìm thấy mã tài khoản Admin. Vui lòng đăng xuất và đăng nhập lại.',
        isError: true,
      );
      return;
    }

    _confirming = true;
    final bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Xác nhận duyệt đối soát'),
            content: Text(
              'Phiếu: ${item.maDs}\n'
              'Shipper: ${item.maSp}\n'
              'Số tiền nộp: ${_formatMoney(item.tongTienNop)}\n\n'
              'Sau khi duyệt, số tiền này sẽ được trừ khỏi số dư ví COD '
              'của shipper.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _primaryRed),
                child: const Text('Duyệt'),
              ),
            ],
          );
        },
      );
    } finally {
      _confirming = false;
    }

    if (mounted &&
        revision == ApiService.sessionRevision &&
        confirmed == true) {
      await _approve(item);
    }
  }

  Future<void> _approve(CodModel item) async {
    if (!mounted || _isApproving) return;
    final adminMaTk = _adminMaTk;

    if (adminMaTk == null || adminMaTk.isEmpty) {
      _showMessage('Không tìm thấy mã tài khoản Admin.', isError: true);
      return;
    }

    setState(() => _isApproving = true);

    try {
      final success = await ApiService.duyetPhieuDoiSoat({
        'maDs': item.maDs,
        'maNguoiDuyet': adminMaTk,
        'hanhDong': 'DaDuyet',
      });

      if (!mounted) return;

      if (!success) {
        _showMessage('Duyệt phiếu không thành công.', isError: true);
        return;
      }

      _showMessage('Đã duyệt phiếu ${item.maDs} thành công.');
      await _fetchCodData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  void _showDetail(CodModel item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Phiếu đối soát ${item.maDs}'),
          content: Text(
            'Mã shipper: ${item.maSp}\n'
            'Ngày gửi: ${_formatDate(item.ngayDoiSoat)}\n'
            'Tổng tiền nộp: ${_formatMoney(item.tongTienNop)}\n'
            'Trạng thái: ${_statusText(item.trangThai)}\n'
            'Người duyệt: ${item.nguoiDuyet ?? "Chưa có"}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
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

  String _formatDate(DateTime? value) {
    if (value == null) return 'Không rõ';

    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _statusText(String status) {
    final normalized = status.trim().toUpperCase().replaceAll('_', '');

    switch (normalized) {
      case 'CHODUYET':
        return 'Chờ duyệt';
      case 'DADUYET':
        return 'Đã duyệt';
      case 'TUCHOI':
        return 'Từ chối';
      default:
        return status.isEmpty ? 'Không rõ' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _codList.fold<double>(
      0,
      (sum, item) => sum + item.tongTienNop,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Duyệt đối soát COD',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isApproving)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: (_isLoading || _isApproving)
                      ? null
                      : _fetchCodData,
                  tooltip: 'Tải lại',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard(
                  'Phiếu chờ duyệt',
                  '${_codList.length}',
                  Colors.orange,
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  'Tổng tiền chờ đối soát',
                  _formatMoney(totalPending),
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryRed),
                    )
                  : _error != null
                  ? _buildError()
                  : _codList.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có phiếu đối soát nào đang chờ duyệt.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _codList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _codList[index];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange.shade50,
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Phiếu ${item.maDs}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Shipper: ${item.maSp}'),
                                      Text(
                                        'Ngày gửi: '
                                        '${_formatDate(item.ngayDoiSoat)}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatMoney(item.tongTienNop),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _isApproving
                                      ? null
                                      : () => _showDetail(item),
                                  child: const Text('Xem'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: _isApproving
                                      ? null
                                      : () => _confirmApprove(item),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primaryRed,
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Duyệt'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchCodData,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
