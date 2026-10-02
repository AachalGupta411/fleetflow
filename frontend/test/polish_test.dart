import 'package:fleetflow/core/network/api_messages.dart';
import 'package:fleetflow/core/router/app_routes.dart';
import 'package:fleetflow/core/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api failures use readable messages and keep specific server text', () {
    expect(
      friendlyApiMessage(network: true),
      contains('Unable to connect to FleetFlow'),
    );
    expect(
      friendlyApiMessage(statusCode: 403),
      "You don't have permission to perform this action.",
    );
    expect(friendlyApiMessage(statusCode: 401), 'Your session expired. Sign in again.');
    expect(
      friendlyApiMessage(statusCode: 409, serverDetail: 'Vehicle number is already in use'),
      'Vehicle number is already in use',
    );
    expect(
      friendlyApiMessage(statusCode: 500, serverDetail: 'Traceback (most recent call last)'),
      'FleetFlow could not complete that request.',
    );
  });

  test('offline and sync banners stay explicit', () {
    expect(
      connectionBanner(online: false, pending: 1, phase: SyncPhase.idle),
      contains('Offline'),
    );
    expect(
      connectionBanner(online: true, pending: 0, phase: SyncPhase.syncing),
      'Syncing queued delivery actions.',
    );
    expect(
      connectionBanner(online: true, pending: 2, phase: SyncPhase.failed),
      contains('Sync failed'),
    );
    expect(connectionBanner(online: true, pending: 0, phase: SyncPhase.idle), isNull);
  });

  test('roles stay on their own home routes', () {
    expect(homeForRole('CUSTOMER'), AppRoutes.customer);
    expect(homeForRole('DRIVER'), AppRoutes.driver);
    expect(homeForRole('FLEET_MANAGER'), AppRoutes.manager);
    expect(homeForRole('ADMIN'), AppRoutes.admin);
    expect(homeForRole('GUEST'), AppRoutes.login);
  });
}
