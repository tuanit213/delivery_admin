import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final percent = TextEditingController(),
      customer = TextEditingController(),
      reference = TextEditingController(),
      discount = TextEditingController(text: '0'),
      until = TextEditingController();
  List<dynamic> drivers = [], contracts = [], customers = [];
  String? selected, error;
  Map<String, dynamic>? salary;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    until.text = DateTime.now()
        .add(const Duration(days: 365))
        .toIso8601String()
        .split('T')
        .first;
    load();
  }

  @override
  void dispose() {
    for (final c in [percent, customer, reference, discount, until]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> action(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    await action(() async {
      final results = await Future.wait([
        ApiService.getJson('/identity/shippers'),
        ApiService.getJson('/finance/earning-policy'),
        ApiService.getJson('/finance/contracts'),
        ApiService.getJson('/identity/customers'),
      ]);
      if (!mounted) return;
      setState(() {
        drivers = results[0] as List;
        percent.text = (results[1] as Map)['commissionPercent'].toString();
        contracts = results[2] as List;
        customers = results[3] as List;
      });
    });
  }

  Future<void> showSalary() async {
    if (selected == null) return;
    await action(() async {
      final data = await ApiService.getJson('/finance/salary/${selected!}');
      if (mounted) {
        setState(() => salary = Map<String, dynamic>.from(data as Map));
      }
    });
  }

  Future<void> savePolicy() async {
    await action(() async {
      final value = double.tryParse(percent.text);
      if (value == null || !value.isFinite || value < 0 || value > 100) {
        throw Exception('Tỷ lệ phải từ 0 đến 100');
      }
      await ApiService.putJson('/finance/earning-policy', {
        'commissionPercent': value,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu; chỉ áp dụng cho đơn hoàn tất từ bây giờ.'),
          ),
        );
      }
    });
  }

  Future<void> saveContract() async {
    await action(() async {
      final value = double.tryParse(discount.text);
      final dateText = until.text.trim();
      final date = DateTime.tryParse(dateText);
      final validDate =
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText) &&
          date != null &&
          date.toIso8601String().split('T').first == dateText;
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value > 100 ||
          !validDate ||
          customer.text.trim().isEmpty ||
          reference.text.trim().isEmpty) {
        throw Exception(
          'Kiểm tra mã hợp đồng, giảm giá 0–100 và ngày YYYY-MM-DD',
        );
      }
      await ApiService.putJson('/finance/contracts/${customer.text.trim()}', {
        'reference': reference.text.trim(),
        'discountPercent': value,
        'validUntil': DateTime.utc(
          date.year,
          date.month,
          date.day + 1,
        ).subtract(const Duration(microseconds: 1)).toIso8601String(),
      });
      final data = await ApiService.getJson('/finance/contracts');
      if (mounted) setState(() => contracts = data as List);
    });
  }

  Widget field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Thu nhập & hợp đồng',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại dữ liệu'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Thu nhập được ghi nhận theo tỷ lệ phí giao hàng đã cấu hình.',
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tỷ lệ thu nhập tài xế',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              field(percent, 'Phần trăm phí giao hàng (%)'),
              FilledButton(
                onPressed: busy ? null : savePolicy,
                child: const Text('Lưu tỷ lệ'),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tài xế'),
                items: drivers
                    .map(
                      (d) => DropdownMenuItem(
                        value: d['maSp'].toString(),
                        child: Text(
                          d['hoTen'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        setState(() {
                          selected = value;
                          salary = null;
                        });
                        showSalary();
                      },
              ),
              if (salary != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Tháng ${salary!['month']}/${salary!['year']} • ${salary!['deliveryCount']} đơn • Thu nhập ${salary!['totalEarnings']}đ',
                ),
                ...((salary!['items'] as List).map(
                  (item) => ListTile(
                    title: Text(item['orderId'].toString()),
                    subtitle: Text(
                      'COD ${item['codAmount']}đ • Thu nhập ${item['earning']}đ',
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chính sách hợp đồng khách hàng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Giảm phần trăm phí cho đơn mới, không sửa giá các đơn đã tạo. Giảm 0% để ngừng ưu đãi.',
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chọn khách hàng'),
                items: customers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['maKh'].toString(),
                        child: Text(
                          '${c['hoTen']} • ${c['soDienThoai'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  customer.text = id ?? '';
                },
              ),
              field(customer, 'Mã khách hàng (UUID)'),
              field(reference, 'Mã hợp đồng'),
              field(discount, 'Giảm phí (%)'),
              field(until, 'Hiệu lực đến ngày (YYYY-MM-DD)'),
              FilledButton(
                onPressed: busy ? null : saveContract,
                child: const Text('Lưu hợp đồng'),
              ),
              ...contracts.map(
                (item) => ListTile(
                  title: Text(
                    '${item['reference']} • ${item['discountPercent']}%',
                  ),
                  subtitle: Text(
                    '${item['customerId']} • ${item['validUntil']}',
                  ),
                  onTap: () {
                    customer.text = item['customerId'].toString();
                    reference.text = item['reference'].toString();
                    discount.text = item['discountPercent'].toString();
                    until.text = item['validUntil'].toString().split('T').first;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
