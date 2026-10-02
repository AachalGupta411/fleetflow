import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/admin/user_form_screen.dart';
import '../../screens/admin/users_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/customer/create_shipment_screen.dart';
import '../../screens/customer/customer_home_screen.dart';
import '../../screens/customer/customer_shipment_screen.dart';
import '../../screens/customer/proof_screen.dart';
import '../../screens/customer/shipment_tracking_screen.dart';
import '../../screens/driver/fail_delivery_screen.dart';
import '../../screens/driver/pod_flow_screen.dart';
import '../../screens/manager/analytics_screen.dart';
import '../../screens/manager/delivery_events_screen.dart';
import '../../screens/manager/fleet_board_screen.dart';
import '../../screens/manager/fuel_entry_screen.dart';
import '../../screens/manager/operations_dashboard_screen.dart';
import '../../screens/manager/pricing_screen.dart';
import '../../screens/manager/ops_driver_screen.dart';
import '../../screens/manager/ops_vehicle_screen.dart';
import '../../screens/shared/notifications_screen.dart';
import '../../screens/customer/shipment_list_screen.dart';
import '../../screens/driver/delivery_detail_screen.dart';
import '../../screens/driver/driver_home_screen.dart';
import '../../screens/home/landing_screen.dart';
import '../../screens/manager/driver_form_screen.dart';
import '../../screens/manager/fleet_map_screen.dart';
import '../../screens/manager/drivers_screen.dart';
import '../../screens/manager/manager_home_screen.dart';
import '../../screens/manager/manager_shipment_screen.dart';
import '../../screens/manager/manager_shipments_screen.dart';
import '../../screens/manager/vehicle_form_screen.dart';
import '../../screens/manager/vehicles_screen.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('That page is not available.')),
    ),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      final isPublic = location == AppRoutes.home ||
          location == AppRoutes.login ||
          location == AppRoutes.register;
      if (!auth.ready) {
        return isPublic ? null : AppRoutes.home;
      }
      final user = auth.user;
      if (user == null) {
        return isPublic ? null : AppRoutes.login;
      }
      if (isPublic) {
        return homeForRole(user.role);
      }
      if (!_allows(user.role, location)) {
        return homeForRole(user.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.home, builder: (context, state) => const LandingScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.customer,
        builder: (context, state) => const CustomerHomeScreen(),
        routes: [
          GoRoute(path: 'alerts', builder: (context, state) => const NotificationsScreen()),
          GoRoute(
            path: 'shipments',
            builder: (context, state) => const ShipmentListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateShipmentScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    CustomerShipmentScreen(shipmentId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'track',
                    builder: (context, state) =>
                        ShipmentTrackingScreen(shipmentId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'proof',
                    builder: (context, state) => ProofScreen(shipmentId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.driver,
        builder: (context, state) => const DriverHomeScreen(),
        routes: [
          GoRoute(path: 'alerts', builder: (context, state) => const NotificationsScreen()),
          GoRoute(
            path: 'deliveries/:id',
            builder: (context, state) =>
                DeliveryDetailScreen(shipmentId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'pod',
                builder: (context, state) => PodFlowScreen(shipmentId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'fail',
                builder: (context, state) => FailDeliveryScreen(shipmentId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.manager,
        builder: (context, state) => const ManagerHomeScreen(),
        routes: [
          GoRoute(path: 'fleet', builder: (context, state) => const FleetMapScreen()),
          GoRoute(path: 'events', builder: (context, state) => const DeliveryEventsScreen()),
          GoRoute(path: 'alerts', builder: (context, state) => const NotificationsScreen()),
          GoRoute(
            path: 'operations',
            builder: (context, state) => const OperationsDashboardScreen(admin: false),
          ),
          GoRoute(path: 'pricing', builder: (context, state) => const PricingScreen()),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const AnalyticsScreen(admin: false),
            routes: [
              GoRoute(
                path: 'drivers/:id',
                builder: (context, state) => OpsDriverScreen(driverId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'board',
            builder: (context, state) => const FleetBoardScreen(admin: false),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    OpsVehicleScreen(vehicleId: state.pathParameters['id']!, admin: false),
                routes: [
                  GoRoute(
                    path: 'fuel',
                    builder: (context, state) => FuelEntryScreen(vehicleId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'shipments',
            builder: (context, state) => const ManagerShipmentsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ManagerShipmentScreen(shipmentId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'proof',
                    builder: (context, state) => ProofScreen(shipmentId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'drivers',
            builder: (context, state) => const DriversScreen(createPath: AppRoutes.managerDriverNew),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const DriverFormScreen()),
            ],
          ),
          GoRoute(
            path: 'vehicles',
            builder: (context, state) =>
                const VehiclesScreen(createPath: AppRoutes.managerVehicleNew),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const VehicleFormScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const ManagerHomeScreen(admin: true),
        routes: [
          GoRoute(path: 'fleet', builder: (context, state) => const FleetMapScreen()),
          GoRoute(path: 'events', builder: (context, state) => const DeliveryEventsScreen()),
          GoRoute(path: 'alerts', builder: (context, state) => const NotificationsScreen()),
          GoRoute(
            path: 'operations',
            builder: (context, state) => const OperationsDashboardScreen(admin: true),
          ),
          GoRoute(path: 'pricing', builder: (context, state) => const PricingScreen()),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const AnalyticsScreen(admin: true),
            routes: [
              GoRoute(
                path: 'drivers/:id',
                builder: (context, state) => OpsDriverScreen(driverId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'board',
            builder: (context, state) => const FleetBoardScreen(admin: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    OpsVehicleScreen(vehicleId: state.pathParameters['id']!, admin: true),
                routes: [
                  GoRoute(
                    path: 'fuel',
                    builder: (context, state) => FuelEntryScreen(vehicleId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'users',
            builder: (context, state) => const UsersScreen(),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const UserFormScreen()),
            ],
          ),
          GoRoute(
            path: 'drivers',
            builder: (context, state) => const DriversScreen(createPath: AppRoutes.adminDriverNew),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const DriverFormScreen()),
            ],
          ),
          GoRoute(
            path: 'vehicles',
            builder: (context, state) => const VehiclesScreen(createPath: AppRoutes.adminVehicleNew),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const VehicleFormScreen()),
            ],
          ),
          GoRoute(
            path: 'shipments',
            builder: (context, state) => const ManagerShipmentsScreen(admin: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ManagerShipmentScreen(shipmentId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'proof',
                    builder: (context, state) => ProofScreen(shipmentId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

bool _allows(String role, String location) {
  if (location.startsWith('/admin')) {
    return role == 'ADMIN';
  }
  if (location.startsWith('/manager')) {
    return role == 'FLEET_MANAGER';
  }
  if (location.startsWith('/driver')) {
    return role == 'DRIVER';
  }
  if (location.startsWith('/customer')) {
    return role == 'CUSTOMER';
  }
  return false;
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}
