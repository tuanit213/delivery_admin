import 'package:flutter/material.dart';

class WarningNoteCard extends StatelessWidget {
  const WarningNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Lưu ý vận hành',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '• Cấu hình phí được dùng khi tính báo giá mới; phí của đơn đã tạo được giữ nguyên.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 8),
          Text(
            '• Tài xế nhận thông báo khi trang tài xế đang mở; hợp đồng riêng được quản lý tại Thu nhập & hợp đồng.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 8),
          Text(
            '• Nên tránh thiết lập hệ số vượt quá 2.5x trong các điều kiện bình thường để đảm bảo tính cạnh tranh.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}
