import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class GlobalSearch extends SearchDelegate<String> {
  Future<List<Map<String, String>>>? data;
  Future<List<Map<String, String>>> all() async {
    final results = await Future.wait([
      ApiService.getJson('/order'),
      ApiService.getJson('/identity/shippers'),
    ]);
    return [
      ...(results[0] as List).map(
        (o) => <String, String>{
          'title': o['maDh'].toString(),
          'detail':
              '${o['tenNguoiNhan'] ?? ''} • ${o['sdtNguoiNhan'] ?? ''} • ${o['diaChiGiao'] ?? ''}',
          'route': '/order_detail/${o['maDh']}',
        },
      ),
      ...(results[1] as List).map(
        (s) => <String, String>{
          'title': s['hoTen'].toString(),
          'detail': '${s['soDienThoai'] ?? ''} • ${s['bienSoXe'] ?? ''}',
          'route': Uri(
            path: '/shipper_management',
            queryParameters: {'q': (s['soDienThoai'] ?? s['hoTen']).toString()},
          ).toString(),
        },
      ),
    ];
  }

  @override
  String get searchFieldLabel => 'Mã đơn, người nhận, số điện thoại, tài xế...';
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, String>>>(
    future: data ??= all(),
    builder: (ctx, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text(snapshot.error.toString()));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final q = query.toLowerCase().trim();
      final rows = snapshot.data!
          .where(
            (r) => ('${r['title']!} ${r['detail']!}').toLowerCase().contains(q),
          )
          .take(50)
          .toList();
      if (rows.isEmpty) return const Center(child: Text('Không có kết quả'));
      return ListView(
        children: rows
            .map(
              (r) => ListTile(
                leading: const Icon(Icons.search),
                title: Text(r['title']!),
                subtitle: Text(r['detail']!),
                onTap: () => close(context, r['route']!),
              ),
            )
            .toList(),
      );
    },
  );
}
