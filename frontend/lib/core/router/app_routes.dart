/// Route paths used by GoRouter.
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';

  static const String customer = '/customer';
  static const String customerShipments = '/customer/shipments';
  static const String customerShipmentNew = '/customer/shipments/new';
  static String customerShipment(String id) => '/customer/shipments/$id';
  static String customerTracking(String id) => '/customer/shipments/$id/track';
  static String customerProof(String id) => '/customer/shipments/$id/proof';
  static const String customerAlerts = '/customer/alerts';

  static const String driver = '/driver';
  static String driverDelivery(String id) => '/driver/deliveries/$id';
  static String driverPod(String id) => '/driver/deliveries/$id/pod';
  static String driverFail(String id) => '/driver/deliveries/$id/fail';
  static const String driverAlerts = '/driver/alerts';

  static const String manager = '/manager';
  static const String managerShipments = '/manager/shipments';
  static String managerShipment(String id) => '/manager/shipments/$id';
  static String managerProof(String id) => '/manager/shipments/$id/proof';
  static const String managerDrivers = '/manager/drivers';
  static const String managerDriverNew = '/manager/drivers/new';
  static const String managerFleet = '/manager/fleet';
  static const String managerEvents = '/manager/events';
  static const String managerAlerts = '/manager/alerts';
  static const String managerOperations = '/manager/operations';
  static const String managerPricing = '/manager/pricing';
  static const String managerAnalytics = '/manager/analytics';
  static String managerDriverOps(String id) => '/manager/analytics/drivers/$id';
  static const String managerBoard = '/manager/board';
  static String managerVehicleOps(String id) => '/manager/board/$id';
  static String managerFuel(String id) => '/manager/board/$id/fuel';
  static const String managerVehicles = '/manager/vehicles';
  static const String managerVehicleNew = '/manager/vehicles/new';

  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminUserNew = '/admin/users/new';
  static const String adminDrivers = '/admin/drivers';
  static const String adminDriverNew = '/admin/drivers/new';
  static const String adminVehicles = '/admin/vehicles';
  static const String adminVehicleNew = '/admin/vehicles/new';
  static const String adminFleet = '/admin/fleet';
  static const String adminEvents = '/admin/events';
  static const String adminAlerts = '/admin/alerts';
  static const String adminOperations = '/admin/operations';
  static const String adminPricing = '/admin/pricing';
  static const String adminAnalytics = '/admin/analytics';
  static String adminDriverOps(String id) => '/admin/analytics/drivers/$id';
  static const String adminBoard = '/admin/board';
  static String adminVehicleOps(String id) => '/admin/board/$id';
  static String adminFuel(String id) => '/admin/board/$id/fuel';
  static const String adminShipments = '/admin/shipments';
  static String adminShipment(String id) => '/admin/shipments/$id';
  static String adminProof(String id) => '/admin/shipments/$id/proof';
}

String homeForRole(String role) {
  switch (role) {
    case 'ADMIN':
      return AppRoutes.admin;
    case 'FLEET_MANAGER':
      return AppRoutes.manager;
    case 'DRIVER':
      return AppRoutes.driver;
    case 'CUSTOMER':
      return AppRoutes.customer;
    default:
      return AppRoutes.login;
  }
}
