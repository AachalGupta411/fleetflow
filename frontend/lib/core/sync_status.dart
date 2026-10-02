enum SyncPhase { idle, syncing, failed }

/// Text for the driver connection banner. Null means the banner can stay hidden.
String? connectionBanner({required bool online, required int pending, required SyncPhase phase}) {
  if (!online) {
    return 'Offline. Delivery actions you take will be saved on this device and synchronized when the connection returns.';
  }
  if (phase == SyncPhase.syncing) {
    return 'Syncing queued delivery actions.';
  }
  if (phase == SyncPhase.failed && pending > 0) {
    final noun = pending == 1 ? 'action is' : 'actions are';
    return 'Sync failed. $pending delivery $noun still saved on this device.';
  }
  if (pending > 0) {
    final noun = pending == 1 ? 'action' : 'actions';
    return '$pending delivery $noun waiting to sync.';
  }
  return null;
}
