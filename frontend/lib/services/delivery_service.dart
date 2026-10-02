import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../providers/api_providers.dart';
import 'offline_queue.dart';

String newClientOperationId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '$time-$rand';
}

class DeliveryService {
  DeliveryService(this._client);

  final ApiClient _client;
  DeliveryActionQueue? _queue;

  Future<DeliveryActionQueue> queue() async {
    final existing = _queue;
    if (existing != null) {
      return existing;
    }
    final directory = await _queueDirectory();
    final created = DeliveryActionQueue(File('${directory.path}/queue.json'));
    await created.load();
    _queue = created;
    return created;
  }

  Future<int> pendingCount() async {
    final items = await queue();
    return items.pending.length;
  }

  Future<Map<String, dynamic>> config() async {
    final data = await _client.send('GET', '/api/v1/deliveries/config');
    return data as Map<String, dynamic>;
  }

  Future<bool> arrive({
    required String deliveryId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    return _sendOrQueue(
      deliveryId: deliveryId,
      action: 'ARRIVE',
      payload: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      },
      send: (operationId) => _client.send(
        'POST',
        '/api/v1/deliveries/$deliveryId/arrive',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'client_operation_id': operationId,
        },
      ),
    );
  }

  Future<bool> fail({
    required String deliveryId,
    required String reason,
    String? notes,
    double? latitude,
    double? longitude,
  }) {
    return _sendOrQueue(
      deliveryId: deliveryId,
      action: 'FAIL',
      payload: {
        'reason': reason,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
      },
      send: (operationId) => _client.send(
        'POST',
        '/api/v1/deliveries/$deliveryId/fail',
        body: {
          'reason': reason,
          'notes': notes,
          'latitude': latitude,
          'longitude': longitude,
          'client_operation_id': operationId,
        },
      ),
    );
  }

  Future<bool> submitProof({
    required String deliveryId,
    required String recipientName,
    required double latitude,
    required double longitude,
    required List<int> photo,
    required List<int> signature,
    String? notes,
    double? accuracy,
    void Function(int sent, int total)? onProgress,
  }) async {
    final operationId = newClientOperationId();
    try {
      await _client.send(
        'POST',
        '/api/v1/deliveries/$deliveryId/pod',
        onSendProgress: onProgress,
        body: FormData.fromMap({
          'recipient_name': recipientName,
          'latitude': latitude,
          'longitude': longitude,
          'client_operation_id': operationId,
          'notes': notes,
          'accuracy': accuracy,
          'photo': MultipartFile.fromBytes(
            photo,
            filename: 'proof.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
          'signature': MultipartFile.fromBytes(
            signature,
            filename: 'signature.png',
            contentType: MediaType('image', 'png'),
          ),
        }),
      );
      return false;
    } on ApiException catch (error) {
      if (error.statusCode != null) {
        rethrow;
      }
      final directory = await _queueDirectory();
      final photoFile = File('${directory.path}/$operationId-photo.jpg');
      final signatureFile = File('${directory.path}/$operationId-signature.png');
      await photoFile.writeAsBytes(photo);
      await signatureFile.writeAsBytes(signature);
      await (await queue()).enqueue(
        QueuedDeliveryAction(
          clientOperationId: operationId,
          deliveryId: deliveryId,
          action: 'POD',
          payload: {
            'recipient_name': recipientName,
            'notes': notes,
            'latitude': latitude,
            'longitude': longitude,
            'accuracy': accuracy,
          },
          photoPath: photoFile.path,
          signaturePath: signatureFile.path,
        ),
      );
      return true;
    }
  }

  Future<Map<String, dynamic>> proof(String deliveryId) async {
    final data = await _client.send('GET', '/api/v1/deliveries/$deliveryId/pod');
    return data as Map<String, dynamic>;
  }

  Future<List<int>> proofPhoto(String deliveryId) {
    return _client.getBytes('/api/v1/deliveries/$deliveryId/pod/photo');
  }

  Future<List<int>> proofSignature(String deliveryId) {
    return _client.getBytes('/api/v1/deliveries/$deliveryId/pod/signature');
  }

  Future<List<Map<String, dynamic>>> events(String deliveryId) async {
    final data = await _client.send('GET', '/api/v1/deliveries/$deliveryId/events');
    return (data as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> recentEvents() async {
    final data = await _client.send('GET', '/api/v1/deliveries/events/recent');
    return (data as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final data = await _client.send('GET', '/api/v1/notifications');
    return (data as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
  }

  Future<int> flush() async {
    final stored = await queue();
    var synced = 0;
    for (final action in List<QueuedDeliveryAction>.from(stored.pending)) {
      try {
        if (action.action == 'POD') {
          await _replayProof(action);
        } else {
          final response = await _client.send(
            'POST',
            '/api/v1/sync/delivery-actions',
            body: {
              'actions': [
                {
                  'client_operation_id': action.clientOperationId,
                  'delivery_id': action.deliveryId,
                  'action': action.action,
                  'payload': action.payload,
                },
              ],
            },
          );
          final results = (response as Map<String, dynamic>)['results'] as List<dynamic>;
          final status = (results.first as Map<String, dynamic>)['status'];
          if (status == 'error') {
            continue;
          }
        }
        await stored.remove(action.clientOperationId);
        synced += 1;
      } on ApiException catch (error) {
        if (error.statusCode == null) {
          break;
        }
      }
    }
    return synced;
  }

  Future<void> _replayProof(QueuedDeliveryAction action) async {
    final photo = await File(action.photoPath!).readAsBytes();
    final signature = await File(action.signaturePath!).readAsBytes();
    await _client.send(
      'POST',
      '/api/v1/deliveries/${action.deliveryId}/pod',
      body: FormData.fromMap({
        'recipient_name': action.payload['recipient_name'],
        'latitude': action.payload['latitude'],
        'longitude': action.payload['longitude'],
        'notes': action.payload['notes'],
        'accuracy': action.payload['accuracy'],
        'client_operation_id': action.clientOperationId,
        'photo': MultipartFile.fromBytes(photo, filename: 'proof.jpg', contentType: MediaType('image', 'jpeg')),
        'signature': MultipartFile.fromBytes(
          signature,
          filename: 'signature.png',
          contentType: MediaType('image', 'png'),
        ),
      }),
    );
  }

  Future<bool> _sendOrQueue({
    required String deliveryId,
    required String action,
    required Map<String, dynamic> payload,
    required Future<dynamic> Function(String operationId) send,
  }) async {
    final operationId = newClientOperationId();
    try {
      await send(operationId);
      return false;
    } on ApiException catch (error) {
      if (error.statusCode != null) {
        rethrow;
      }
      await (await queue()).enqueue(
        QueuedDeliveryAction(
          clientOperationId: operationId,
          deliveryId: deliveryId,
          action: action,
          payload: payload,
        ),
      );
      return true;
    }
  }

  Future<Directory> _queueDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/delivery-queue');
    await directory.create(recursive: true);
    return directory;
  }
}

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(ref.watch(apiClientProvider));
});
