import 'package:flutter/material.dart';

import '../../widgets/dark_page.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DarkPage(
      title: 'Pricing',
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Text(
            'These are the FleetFlow commercial options. This screen does not collect payment.',
            style: TextStyle(color: DarkColors.muted, height: 1.4),
          ),
          SizedBox(height: 16),
          _Plan(
            title: 'Standard shipment',
            price: '₹30–100',
            detail: 'Charged per shipment. The exact amount depends on distance and package size.',
          ),
          _Plan(
            title: 'Express delivery',
            price: 'Premium',
            detail: 'A higher-priority shipment. Express is a service tier, not a payment that this app processes.',
          ),
          _Plan(
            title: 'Fleet management',
            price: 'Monthly subscription',
            detail: 'A monthly plan for managers who assign drivers, watch the fleet, and review operations.',
          ),
          _Plan(
            title: 'Enterprise',
            price: 'By vehicle count',
            detail: 'Priced from the number of vehicles on the account. Billing is handled outside FleetFlow.',
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.title, required this.price, required this.detail});

  final String title;
  final String price;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DarkColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: DarkColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: DarkColors.text, height: 1.35)),
        ],
      ),
    );
  }
}
