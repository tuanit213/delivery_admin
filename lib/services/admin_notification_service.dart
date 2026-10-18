import 'package:flutter/foundation.dart';

class AdminNotificationItem {
  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.orderId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? orderId;
  bool isRead;
}

class AdminNotificationService extends ChangeNotifier {
  AdminNotificationService._();

  static final AdminNotificationService instance = AdminNotificationService._();

  final List<AdminNotificationItem> _items = [];

  List<AdminNotificationItem> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  void addOrderOverdue({
    required String orderId,
    required int maxWaitingMinutes,
    required Duration elapsed,
  }) {
    final notificationId = 'order-overdue-$orderId';

    if (_items.any((item) => item.id == notificationId)) {
      return;
    }

    _items.insert(
      0,
      AdminNotificationItem(
        id: notificationId,
        title: 'Đơn hàng quá thời gian chờ',
        message:
            'Đơn $orderId đã chờ ${_formatElapsed(elapsed)}. '
            'Ngưỡng điều phối là $maxWaitingMinutes phút.',
        createdAt: DateTime.now(),
        orderId: orderId,
      ),
    );

    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index == -1 || _items[index].isRead) {
      return;
    }

    _items[index].isRead = true;
    notifyListeners();
  }

  void markAllAsRead() {
    var changed = false;

    for (final item in _items) {
      if (!item.isRead) {
        item.isRead = true;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  static String _formatElapsed(Duration elapsed) {
    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours giờ $minutes phút';
    }

    final totalMinutes = elapsed.inMinutes;

    if (totalMinutes > 0) {
      return '$totalMinutes phút';
    }

    return '${elapsed.inSeconds} giây';
  }
}
