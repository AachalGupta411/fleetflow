import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/delivery_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';

class PodFlowScreen extends ConsumerStatefulWidget {
  const PodFlowScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  ConsumerState<PodFlowScreen> createState() => _PodFlowScreenState();
}

class _PodFlowScreenState extends ConsumerState<PodFlowScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _signature = SignatureController(penStrokeWidth: 3, exportBackgroundColor: Colors.white);
  final _draft = SignatureDraft();
  Uint8List? _photo;
  Uint8List? _signatureBytes;
  var _step = 0;
  var _saving = false;
  var _progress = 0.0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FleetScaffold(
      title: 'Proof of delivery',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Step ${_step + 1} of 3', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          if (_step == 0) ..._photoStep(),
          if (_step == 1) ..._signatureStep(),
          if (_step == 2) ..._reviewStep(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  List<Widget> _photoStep() {
    return [
      if (_photo != null) Image.memory(_photo!, height: 220, fit: BoxFit.cover),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => _pick(ImageSource.camera), child: const Text('Take photo')),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => _pick(ImageSource.gallery), child: const Text('Choose photo')),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _photo == null ? null : () => setState(() => _step = 1),
        child: const Text('Continue'),
      ),
    ];
  }

  List<Widget> _signatureStep() {
    return [
      const Text('Recipient signature'),
      const SizedBox(height: 8),
      Container(
        height: (MediaQuery.sizeOf(context).height * 0.28).clamp(160, 240),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Signature(
          controller: _signature,
          backgroundColor: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          TextButton(
            onPressed: () {
              _signature.clear();
              _draft.clear();
              setState(() => _signatureBytes = null);
            },
            child: const Text('Clear'),
          ),
          const Spacer(),
          FilledButton(onPressed: _confirmSignature, child: const Text('Confirm signature')),
        ],
      ),
    ];
  }

  List<Widget> _reviewStep() {
    return [
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Recipient name')),
      const SizedBox(height: 12),
      TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), minLines: 2, maxLines: 4),
      const SizedBox(height: 12),
      if (_photo != null) Image.memory(_photo!, height: 140, fit: BoxFit.cover),
      if (_signatureBytes != null) ...[
        const SizedBox(height: 8),
        Image.memory(_signatureBytes!, height: 80, fit: BoxFit.contain),
      ],
      if (_saving) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Uploading…' : 'Complete delivery')),
    ];
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 70);
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = 'Could not read that photo.');
    }
  }

  Future<void> _confirmSignature() async {
    if (_signature.isEmpty) {
      setState(() => _error = 'Sign in the box before confirming.');
      return;
    }
    final bytes = await _signature.toPngBytes();
    if (bytes == null) {
      setState(() => _error = 'Could not save the signature.');
      return;
    }
    _draft.markInk();
    setState(() {
      _signatureBytes = bytes;
      _error = null;
      _step = 2;
    });
  }

  Future<void> _submit() async {
    final error = validateProof(
      recipientName: _name.text,
      hasPhoto: _photo != null,
      hasSignature: _signatureBytes != null && _draft.canConfirm,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final deliveryId = ref.read(shipmentProvider(widget.shipmentId)).value?.deliveryId;
    if (deliveryId == null) {
      setState(() => _error = 'This shipment has no delivery record yet.');
      return;
    }
    final fix = await ref.read(trackingSessionProvider.notifier).captureFix();
    if (fix == null) {
      setState(() => _error = 'A current GPS fix is required to complete the delivery.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progress = 0;
    });
    try {
      final queued = await ref.read(deliveryServiceProvider).submitProof(
            deliveryId: deliveryId,
            recipientName: _name.text.trim(),
            notes: _notes.text.trim(),
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracy: fix.accuracy,
            photo: _photo!,
            signature: _signatureBytes!,
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _progress = sent / total);
              }
            },
          );
      ref.read(pendingActionsProvider.notifier).setCount(await ref.read(deliveryServiceProvider).pendingCount());
      ref.invalidate(shipmentProvider(widget.shipmentId));
      ref.invalidate(shipmentListProvider);
      ref.invalidate(myDriverProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Saved on this device. It will sync when you are back online.'
                : 'Delivery completed.',
          ),
        ),
      );
      context.go('/driver');
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
