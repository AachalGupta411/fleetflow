import 'dart:io';

import 'package:fleetflow/core/delivery_rules.dart';
import 'package:fleetflow/services/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proof and failure validation', () {
    expect(validateRecipientName('A'), 'Enter the recipient name.');
    expect(validateRecipientName('Asha'), isNull);
    expect(
      validateProof(recipientName: 'Asha', hasPhoto: false, hasSignature: true),
      'Add a delivery photo.',
    );
    expect(
      validateProof(recipientName: 'Asha', hasPhoto: true, hasSignature: false),
      'Add the recipient signature.',
    );
    expect(validateProof(recipientName: 'Asha', hasPhoto: true, hasSignature: true), isNull);
    expect(validateFailure(reason: null, notes: ''), 'Choose a failure reason.');
    expect(validateFailure(reason: 'OTHER', notes: 'no'), 'Add a short note for this failure.');
    expect(validateFailure(reason: 'CUSTOMER_UNAVAILABLE', notes: ''), isNull);
  });

  test('signature draft and geofence state', () {
    final draft = SignatureDraft();
    expect(draft.canConfirm, isFalse);
    draft.markInk();
    expect(draft.canConfirm, isTrue);
    draft.clear();
    expect(draft.canConfirm, isFalse);
    expect(insideGeofence(40, defaultGeofenceRadiusMeters), isTrue);
    expect(insideGeofence(140, defaultGeofenceRadiusMeters), isFalse);
    expect(distanceMeters(19.076, 72.877, 19.076, 72.877), 0);
  });

  test('offline queue keeps one copy of an operation and removes it after sync', () async {
    final file = File('${Directory.systemTemp.path}/fleetflow-queue-${DateTime.now().microsecondsSinceEpoch}.json');
    final queue = DeliveryActionQueue(file);
    await queue.load();
    final action = QueuedDeliveryAction(
      clientOperationId: 'op-12345678',
      deliveryId: 'delivery-1',
      action: 'FAIL',
      payload: {'reason': 'ACCESS_ISSUE'},
    );
    await queue.enqueue(action);
    await queue.enqueue(action);
    expect(queue.pending, hasLength(1));
    final reloaded = DeliveryActionQueue(file);
    await reloaded.load();
    expect(reloaded.pending.single.clientOperationId, 'op-12345678');
    await reloaded.remove('op-12345678');
    expect(reloaded.pending, isEmpty);
    if (file.existsSync()) {
      await file.delete();
    }
  });
}