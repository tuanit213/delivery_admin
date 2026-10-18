import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import 'package:admin/services/api_service.dart';

class ApproveShipperScreen extends StatefulWidget {
  final String shipperId;

  const ApproveShipperScreen({super.key, required this.shipperId});

  @override
  State<ApproveShipperScreen> createState() => _ApproveShipperScreenState();
}

class _ApproveShipperScreenState extends State<ApproveShipperScreen> {
  bool _checkCccd = false;
  bool _checkGplx = false;
  bool _checkPhoto = false;
  bool _checkHistory = false;

  bool _isSubmitting = false;
  bool _confirming = false;
  String? _loadError;
  bool _isLoadingDetail = true;

  Map<String, dynamic>? _shipperData;

  @override
  void initState() {
    super.initState();
    _loadShipperDetail();
  }

  Future<void> _loadShipperDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _loadError = null;
    });
    try {
      final data = await ApiService.getChiTietShipper(widget.shipperId);
      if (!mounted) return;
      setState(() {
        _shipperData = data;
        _isLoadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _loadError = 'Không thể tải hồ sơ. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _processApproval({required bool isApproved}) async {
    if (_isSubmitting || _confirming || _shipperData == null) return;
    final revision = ApiService.sessionRevision;
    if (!isApproved ||
        !(_checkCccd && _checkGplx && _checkPhoto && _checkHistory)) {
      _confirming = true;
      final confirm = await _showConfirmDialog(
        title: isApproved ? 'Cảnh báo checklist' : 'Từ chối hồ sơ?',
        content: isApproved
            ? 'Bạn chưa tích chọn đủ các mục kiểm tra. Bạn có chắc chắn vẫn muốn phê duyệt hồ sơ này?'
            : 'Tài xế sẽ không được bật Online và nhận đơn mới. Bạn muốn tiếp tục?',
      );
      _confirming = false;
      if (confirm != true) return;
    }

    if (!mounted || revision != ApiService.sessionRevision) return;
    setState(() => _isSubmitting = true);

    try {
      await ApiService.duyetHoSoShipper(
        maShipper: widget.shipperId,
        isApproved: isApproved,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved
                ? 'Đã phê duyệt hồ sơ shipper thành công!'
                : 'Đã từ chối hồ sơ shipper!',
          ),
          backgroundColor: isApproved
              ? AppColors.statusGreen
              : AppColors.statusRed,
        ),
      );

      _returnToList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _returnToList() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      context.go('/shipper_management');
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Tiếp tục',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _previewImage(String title, String? imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image, size: 100),
                    )
                  : SizedBox(
                      height: 250,
                      child: Center(child: Text('Không có hình ảnh hiển thị')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              TextButton(
                onPressed: _loadShipperDetail,
                child: const Text('Thử lại hồ sơ'),
              ),
              TextButton(
                onPressed: _returnToList,
                child: const Text('Quay lại danh sách'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chi tiết phê duyệt hồ sơ đăng ký mới',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Mã hồ sơ: ${widget.shipperId} | Tên: ${_shipperData?['hoTen'] ?? 'N/A'}',
                          style: const TextStyle(color: AppColors.textSubtitle),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : _returnToList,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildDocumentSection()),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _buildChecklistSection()),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _buildDocumentSection(),
                      const SizedBox(height: 24),
                      _buildChecklistSection(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giấy tờ tải lên (Nhấn để phóng to)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildImageCard(
              'Ảnh chân dung',
              Icons.person_pin,
              _shipperData?['anhChanDungUrl'],
            ),
            _buildImageCard(
              'CCCD Mặt trước/sau',
              Icons.badge,
              _shipperData?['anhCccdUrl'],
            ),
            _buildImageCard(
              'GPLX & Cà vẹt xe',
              Icons.two_wheeler,
              _shipperData?['anhGplxUrl'],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    return Material(
      color: AppColors.backgroundGray,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danh mục kiểm tra',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('CCCD còn thời hạn hiệu lực'),
              value: _checkCccd,
              activeColor: AppColors.primaryRed,
              onChanged: _isSubmitting
                  ? null
                  : (val) => setState(() => _checkCccd = val!),
            ),
            CheckboxListTile(
              title: const Text('GPLX phù hợp hạng tải trọng'),
              value: _checkGplx,
              activeColor: AppColors.primaryRed,
              onChanged: _isSubmitting
                  ? null
                  : (val) => setState(() => _checkGplx = val!),
            ),
            CheckboxListTile(
              title: const Text('Ảnh chân dung khớp với CCCD'),
              value: _checkPhoto,
              activeColor: AppColors.primaryRed,
              onChanged: _isSubmitting
                  ? null
                  : (val) => setState(() => _checkPhoto = val!),
            ),
            CheckboxListTile(
              title: const Text('Tra cứu lịch sử vi phạm (An toàn)'),
              value: _checkHistory,
              activeColor: AppColors.primaryRed,
              onChanged: _isSubmitting
                  ? null
                  : (val) => setState(() => _checkHistory = val!),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRed,
                      side: const BorderSide(color: AppColors.statusRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _processApproval(isApproved: false),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Từ chối hồ sơ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _processApproval(isApproved: true),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Phê duyệt hồ sơ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(String label, IconData icon, String? imageUrl) {
    return InkWell(
      onTap: () => _previewImage(label, imageUrl),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) =>
                        Icon(icon, size: 48, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Icon(icon, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
