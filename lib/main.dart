import 'core/theme/admin_pixel_theme.dart';
import 'features/finance/finance_screen.dart';

import 'package:admin/services/api_service.dart';

import 'package:admin/features/auth/screens/login_screen.dart';
import 'package:admin/features/cod_reconciliation/screens/cod_review_screen.dart';
import 'package:admin/features/dashboard/screens/admin_main_layout.dart';
import 'package:admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:admin/features/dispatch_center/screens/dispatch_center_screen.dart';
import 'package:admin/features/dispatch_map/screens/dispatch_map_screen.dart';
import 'package:admin/features/order_management/screens/admin_create_order_screen.dart';
import 'package:admin/features/order_management/screens/order_detail_screen.dart';
import 'package:admin/features/order_management/screens/order_list_screen.dart';
import 'package:admin/features/shipper_management/screens/approve_shipper_screen.dart';
import 'package:admin/features/shipper_management/screens/shipper_list_screen.dart';
import 'package:admin/features/system_config/screens/config_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadToken();
  runApp(const LogiRouteAdminApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: ApiService.authenticated,
  redirect: (context, state) {
    final loginPage = state.uri.path == '/login';
    if (!ApiService.authenticated.value && !loginPage) return '/login';
    if (ApiService.authenticated.value && loginPage) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) {
        return AdminMainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/finance',
          builder: (context, state) => const FinanceScreen(),
        ),

        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        GoRoute(
          path: '/dispatch_map',
          builder: (context, state) => const DispatchMapScreen(),
        ),

        GoRoute(
          path: '/dispatch_center',
          builder: (context, state) => const DispatchCenterScreen(),
        ),

        GoRoute(
          path: '/order_management',
          builder: (context, state) => const OrderListScreen(),
        ),

        GoRoute(
          path: '/order_detail/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId'] ?? '';
            return OrderDetailScreen(orderId: orderId);
          },
        ),

        GoRoute(
          path: '/admin_create_order',
          builder: (context, state) => const AdminCreateOrderScreen(),
        ),

        GoRoute(
          path: '/cod_reconciliation',
          builder: (context, state) => const CodReviewScreen(),
        ),

        GoRoute(
          path: '/shipper_management',
          builder: (context, state) => ShipperListScreen(
            initialSearch: state.uri.queryParameters['q'] ?? '',
          ),
        ),

        GoRoute(
          path: '/approve_shipper/:shipperId',
          builder: (context, state) {
            final shipperId = state.pathParameters['shipperId'] ?? '';
            return ApproveShipperScreen(shipperId: shipperId);
          },
        ),

        GoRoute(
          path: '/system_config',
          builder: (context, state) => const SystemConfigScreen(),
        ),
      ],
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '404 - Không tìm thấy trang: ${state.uri}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Quay lại Trang chủ'),
          ),
        ],
      ),
    ),
  ),
);

class LogiRouteAdminApp extends StatelessWidget {
  const LogiRouteAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LogiRoute Admin - Hệ Thống Điều Phối Vận Tải TP.HCM',
      debugShowCheckedModeBanner: false,
      theme: adminPixelTheme(),
      routerConfig: _router,
    );
  }
}
