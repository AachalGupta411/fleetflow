import 'dart:math' as math;

const int defaultGeofenceRadiusMeters = 100;

const failureReasons = <String, String>{
  'CUSTOMER_UNAVAILABLE': 'Customer unavailable',
  'WRONG_ADDRESS': 'Wrong address',
  'CUSTOMER_REFUSED': 'Customer refused',
  'ACCESS_ISSUE': 'Access issue',
  'VEHICLE_ISSUE': 'Vehicle issue',
  'DAMAGED_PACKAGE': 'Damaged package',
  'OTHER': 'Other',
};

const deliverySteps = ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'ARRIVING', 'DELIVERED'];

String? validateRecipientName(String value) {
  if (value.trim().length < 2) {
    return 'Enter the recipient name.';
  }
  return null;
}

String? validateProof({required String recipientName, required bool hasPhoto, required bool hasSignature}) {
  final nameError = validateRecipientName(recipientName);
  if (nameError != null) {
    return nameError;
  }
  if (!hasPhoto) {
    return 'Add a delivery photo.';
  }
  if (!hasSignature) {
    return 'Add the recipient signature.';
  }
  return null;
}

String? validateFailure({required String? reason, required String notes}) {
  if (reason == null || !failureReasons.containsKey(reason)) {
    return 'Choose a failure reason.';
  }
  if (reason == 'OTHER' && notes.trim().length < 3) {
    return 'Add a short note for this failure.';
  }
  return null;
}

double distanceMeters(double latitudeA, double longitudeA, double latitudeB, double longitudeB) {
  const earth = 6371000.0;
  final lat1 = _radians(latitudeA);
  final lat2 = _radians(latitudeB);
  final dLat = _radians(latitudeB - latitudeA);
  final dLon = _radians(longitudeB - longitudeA);
  final haversine = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(haversine.toDouble()));
}

bool insideGeofence(double meters, int radius) => meters <= radius;

double _radians(double degrees) => degrees * math.pi / 180;

class SignatureDraft {
  var hasInk = false;

  void markInk() => hasInk = true;

  void clear() => hasInk = false;

  bool get canConfirm => hasInk;
}
