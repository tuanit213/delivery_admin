import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/admin_main_layout.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dispatch_map/screens/dispatch_map_screen.dart';
import '../../features/dispatch_center/screens/dispatch_center_screen.dart';
import '../../features/order_management/screens/order_list_screen.dart';
import '../../features/shipper_management/screens/shipper_list_screen.dart';
import '../../features/cod_reconciliation/screens/cod_review_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dispatch_map',
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
          path: '/shipper_management',
          builder: (context, state) => const ShipperListScreen(),
        ),
        GoRoute(
          path: '/cod_reconciliation',
          builder: (context, state) => const CodReviewScreen(),
        ),
      ],
    ),
  ],
);
