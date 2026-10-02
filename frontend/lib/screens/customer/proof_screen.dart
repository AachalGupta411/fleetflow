import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/logistics_providers.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';

class ProofScreen extends ConsumerWidget {
  const ProofScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipment = ref.watch(shipmentProvider(shipmentId));
    if (shipment.isLoading) {
      return const FleetScaffold(
        title: 'Proof of delivery',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final deliveryId = shipment.value?.deliveryId;
    if (deliveryId == null) {
      return const FleetScaffold(title: 'Proof of delivery', body: EmptyPane(message: 'Proof is not available yet.'));
    }
    final proof = ref.watch(_proofProvider(deliveryId));
    return FleetScaffold(
      title: 'Proof of delivery',
      body: proof.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(message: error.toString(), onRetry: () => ref.invalidate(_proofProvider(deliveryId))),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Recipient: ${item['recipient_name'] ?? 'Not recorded'}'),
            if (item['notes'] != null) ...[
              const SizedBox(height: 8),
              Text('Notes: ${item['notes']}'),
            ],
            const SizedBox(height: 16),
            if (item['photo_available'] == true)
              _BytesImage(loader: () => ref.read(deliveryServiceProvider).proofPhoto(deliveryId)),
            const SizedBox(height: 12),
            if (item['signature_available'] == true)
              _BytesImage(loader: () => ref.read(deliveryServiceProvider).proofSignature(deliveryId)),
          ],
        ),
      ),
    );
  }
}

final _proofProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(deliveryServiceProvider).proof(id);
});

class _BytesImage extends StatefulWidget {
  const _BytesImage({required this.loader});

  final Future<List<int>> Function() loader;

  @override
  State<_BytesImage> createState() => _BytesImageState();
}

class _BytesImageState extends State<_BytesImage> {
  late final Future<List<int>> _bytes = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        return Image.memory(Uint8List.fromList(snapshot.data!), fit: BoxFit.contain);
      },
    );
  }
}
