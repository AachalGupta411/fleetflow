import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync_status.dart';
import '../services/delivery_service.dart';

final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _online(await connectivity.checkConnectivity());
  await for (final update in connectivity.onConnectivityChanged) {
    yield _online(update);
  }
});

bool _online(List<ConnectivityResult> results) {
  return results.any((result) => result != ConnectivityResult.none);
}

class PendingActions extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int value) => state = value;
}

final pendingActionsProvider = NotifierProvider<PendingActions, int>(PendingActions.new);

class SyncPhaseController extends Notifier<SyncPhase> {
  @override
  SyncPhase build() => SyncPhase.idle;

  void setPhase(SyncPhase value) => state = value;
}

final syncPhaseProvider = NotifierProvider<SyncPhaseController, SyncPhase>(SyncPhaseController.new);

final pendingCountLoaderProvider = FutureProvider<int>((ref) async {
  final count = await ref.watch(deliveryServiceProvider).pendingCount();
  ref.read(pendingActionsProvider.notifier).setCount(count);
  return count;
});
