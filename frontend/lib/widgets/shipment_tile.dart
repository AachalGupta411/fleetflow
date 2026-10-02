import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme/app_theme.dart';
import '../models/shipment.dart';
import 'status_badge.dart';

class ShipmentTile extends StatelessWidget {
  const ShipmentTile({
    super.key,
    required this.shipment,
    required this.onTap,
    this.showCustomer = false,
    this.showDate = false,
  });

  final Shipment shipment;
  final VoidCallback onTap;
  final bool showCustomer;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shipment.trackingNumber,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    StatusBadge(value: shipment.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shipment.deliveryAddress,
                  style: const TextStyle(color: AppColors.ink, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (showCustomer) shipment.customerName,
                    prettyLabel(shipment.priority),
                    if (showDate && shipment.createdAt != null) formatAgo(shipment.createdAt!),
                    if (shipment.driverName != null) 'Driver ${shipment.driverName}',
                    if (shipment.vehicleNumber != null) shipment.vehicleNumber!,
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
