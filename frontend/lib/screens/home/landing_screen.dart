import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/connection_status_card.dart';
import '../../widgets/hero_frame.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HeroFrame(
      footer: const HeroStats(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Logistics you can follow, start to finish.',
            style: TextStyle(color: Colors.white, fontSize: 52, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.2),
          ),
          const SizedBox(height: 18),
          const Text(
            'Sign in to open your workspace.',
            style: TextStyle(color: Color(0xFFE6EDF5), fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.login),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Sign in'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF121418),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 18),
          const ConnectionStatusCard(),
        ],
      ),
    );
  }
}
