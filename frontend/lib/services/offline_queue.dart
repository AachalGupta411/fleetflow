import 'dart:convert';
import 'dart:io';

class QueuedDeliveryAction {
  QueuedDeliveryAction({
    required this.clientOperationId,
    required this.deliveryId,
    required this.action,
    required this.payload,
    this.photoPath,
    this.signaturePath,
  });

  final String clientOperationId;
  final String deliveryId;
  final String action;
  final Map<String, dynamic> payload;
  final String? photoPath;
  final String? signaturePath;

  Map<String, dynamic> toJson() => {
        'client_operation_id': clientOperationId,
        'delivery_id': deliveryId,
        'action': action,
        'payload': payload,
        'photo_path': photoPath,
        'signature_path': signaturePath,
      };

  factory QueuedDeliveryAction.fromJson(Map<String, dynamic> json) {
    return QueuedDeliveryAction(
      clientOperationId: json['client_operation_id'] as String,
      deliveryId: json['delivery_id'] as String,
      action: json['action'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      photoPath: json['photo_path'] as String?,
      signaturePath: json['signature_path'] as String?,
    );
  }
}

class DeliveryActionQueue {
  DeliveryActionQueue(this._file);

  final File _file;
  List<QueuedDeliveryAction> _items = [];

  List<QueuedDeliveryAction> get pending => List.unmodifiable(_items);

  Future<void> load() async {
    if (!_file.existsSync()) {
      _items = [];
      return;
    }
    final decoded = jsonDecode(await _file.readAsString());
    if (decoded is! List) {
      _items = [];
      return;
    }
    _items = decoded.map((item) => QueuedDeliveryAction.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> enqueue(QueuedDeliveryAction action) async {
    if (_items.any((item) => item.clientOperationId == action.clientOperationId)) {
      return;
    }
    _items = [..._items, action];
    await _save();
  }

  Future<void> remove(String clientOperationId) async {
    _items = _items.where((item) => item.clientOperationId != clientOperationId).toList();
    await _save();
  }

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_items.map((item) => item.toJson()).toList()));
  }
}
