import '../../../shared/widgets/pixel_brand.dart';
import '../../../shared/widgets/pixel_admin_scene.dart';
import '../../../core/constants/app_colors.dart';
import 'global_search.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/services/admin_notification_service.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminMainLayout extends StatefulWidget {
  final Widget child;

  const AdminMainLayout({super.key, required this.child});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final AdminNotificationService _notificationService =
      AdminNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final compact = MediaQuery.sizeOf(context).width < 1000;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundGray,
      drawer: compact
          ? Drawer(
              width: 260,
              shape: const RoundedRectangleBorder(),
              child: _sidebar(context, currentRoute),
            )
          : null,
      body: Row(
        children: [
          if (!compact) _sidebar(context, currentRoute),
          Expanded(
            child: Column(
              children: [
                compact ? _compactHeader(context) : _buildHeader(context),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactHeader(BuildContext context) => Material(
    color: AppColors.panel,
    child: SafeArea(
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mở menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
            ),
            const Expanded(
              child: Text(
                'LogiRoute Admin',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: () async {
                final route = await showSearch<String>(
                  context: context,
                  delegate: GlobalSearch(),
                );
                if (context.mounted && route != null && route.isNotEmpty) {
                  context.go(route);
                }
              },
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () => _showNotificationMenu(context),
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              tooltip: 'Tạo đơn',
              onPressed: () => context.go('/admin_create_order'),
              icon: const Icon(Icons.add_box_outlined),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sidebar(BuildContext context, String currentRoute) {
    return Container(
      width: 242,
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PixelBrand(compact: true),
                const SizedBox(height: 10),
                const Text(
                  'TRẠM ĐIỀU PHỐI',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 28, height: 4, color: AppColors.amber),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: 'Bảng điều khiển',
                  targetRoute: '/dashboard',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.explore_outlined,
                  title: 'Bản đồ trực tuyến',
                  targetRoute: '/dispatch_map',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.local_shipping_outlined,
                  title: 'Đơn hàng',
                  targetRoute: '/order_management',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.hub_outlined,
                  title: 'Trung tâm điều phối',
                  targetRoute: '/dispatch_center',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Đối soát COD',
                  targetRoute: '/cod_reconciliation',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Tài xế',
                  targetRoute: '/shipper_management',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.payments_outlined,
                  title: 'Thu nhập & hợp đồng',
                  targetRoute: '/finance',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Cấu hình hệ thống',
                  targetRoute: '/system_config',
                  currentRoute: currentRoute,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: pixelPanel(shadow: 3),
              padding: const EdgeInsets.all(2),
              child: const AspectRatio(
                aspectRatio: 3 / 2,
                child: PixelAdminScene(),
              ),
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Quản trị viên',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'LogiRoute Console',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    await ApiService.logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.logout, size: 18, color: Colors.black54),
                      SizedBox(width: 10),
                      Text(
                        'Đăng xuất',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String targetRoute,
    required String currentRoute,
  }) {
    final isSelected = currentRoute.startsWith(targetRoute);
    const primaryRed = Color(0xFF245B69);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? primaryRed : Colors.transparent,
        borderRadius: BorderRadius.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.black87,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          onTap: () {
            _scaffoldKey.currentState?.closeDrawer();
            if (!isSelected) {
              context.go(targetRoute);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showNotificationMenu(BuildContext context) async {
    const primaryRed = Color(0xFF245B69);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selected = await showMenu<AdminNotificationItem>(
      context: context,
      position: RelativeRect.fromLTRB(overlay.size.width - 430, 58, 18, 0),
      constraints: const BoxConstraints(
        minWidth: 380,
        maxWidth: 420,
        maxHeight: 480,
      ),
      items: [
        PopupMenuItem<AdminNotificationItem>(
          enabled: false,
          child: SizedBox(
            width: 380,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_notificationService.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      _notificationService.markAllAsRead();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Đánh dấu đã đọc',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_notificationService.items.isEmpty)
          const PopupMenuItem<AdminNotificationItem>(
            enabled: false,
            child: SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Chưa có thông báo',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ..._notificationService.items.take(10).map((notification) {
            return PopupMenuItem<AdminNotificationItem>(
              value: notification,
              padding: EdgeInsets.zero,
              child: Container(
                width: 400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                color: notification.isRead
                    ? Colors.white
                    : primaryRed.withValues(alpha: 0.04),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: primaryRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: primaryRed,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatNotificationTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );

    if (selected == null) {
      return;
    }

    _notificationService.markAsRead(selected.id);

    if (!context.mounted) {
      return;
    }

    if (selected.orderId != null) {
      context.go(
        '/dispatch_center?orderId=${Uri.encodeComponent(selected.orderId!)}',
      );
    } else {
      context.go('/dispatch_center');
    }
  }

  String _formatNotificationTime(DateTime value) {
    final elapsed = DateTime.now().difference(value);

    if (elapsed.inSeconds < 60) {
      return 'Vừa xong';
    }

    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} phút trước';
    }

    if (elapsed.inHours < 24) {
      return '${elapsed.inHours} giờ trước';
    }

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildHeader(BuildContext context) {
    const primaryRed = Color(0xFF245B69);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'LogiRoute Admin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              height: 38,
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                readOnly: true,
                onTap: () async {
                  final route = await showSearch<String>(
                    context: context,
                    delegate: GlobalSearch(),
                  );
                  if (context.mounted && route != null && route.isNotEmpty) {
                    context.go(route);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm đơn hàng, tài xế...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Color(0xFFCDD4CC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Color(0xFFCDD4CC)),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Thông báo',
                icon: Icon(
                  _notificationService.unreadCount > 0
                      ? Icons.notifications_outlined
                      : Icons.notifications_none_outlined,
                ),
                onPressed: () => _showNotificationMenu(context),
              ),
              if (_notificationService.unreadCount > 0)
                Positioned(
                  right: 3,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: primaryRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _notificationService.unreadCount > 99
                          ? '99+'
                          : '${_notificationService.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Hướng dẫn',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Hướng dẫn LogiRoute'),
                content: const SingleChildScrollView(
                  child: Text(
                    '1. Duyệt hồ sơ tài xế và yêu cầu tài xế bật Online.\n2. Tạo đơn với hai vị trí trên bản đồ; hệ thống tính cước theo đường bộ.\n3. Chọn tài xế trong Trung tâm điều phối và xác nhận phân công.\n4. Tài xế nhận đơn, bắt đầu giao. Khách lấy mã nhận hàng trong chi tiết đơn.\n5. Tài xế nhập mã sau khi giao hàng. COD và thu nhập tự ghi nhận.\n6. Tài xế lập phiếu nộp COD; Admin duyệt sau khi kiểm tra tiền thực nhận.\nGPS chỉ có khi tài xế cho phép chia sẻ. Thông báo tài xế hoạt động khi trang tài xế đang mở.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        '${ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '')}/driver/',
                      ),
                    ),
                    child: const Text('Mở trang tài xế'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => context.go('/admin_create_order'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Tạo đơn mới',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
