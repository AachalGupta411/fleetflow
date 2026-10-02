import 'package:flutter/material.dart';

class HeroFrame extends StatelessWidget {
  const HeroFrame({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hero_truck.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xF0101418), Color(0xC0101418), Color(0x40101418), Color(0x10101418)],
                stops: [0, 0.38, 0.68, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                final inset = wide ? 72.0 : 24.0;
                return Padding(
                  padding: EdgeInsets.fromLTRB(inset, 20, inset, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FleetFlow',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Smart Logistics & Fleet Management',
                        style: TextStyle(color: Color(0xFFD5DDE6), fontSize: 13),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      if (footer != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: wide ? 720 : constraints.maxWidth),
                          child: footer!,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HeroStats extends StatelessWidget {
  const HeroStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Stat('Live', 'Location while a delivery is moving')),
        Expanded(child: _Stat('Proof', 'Photo and signature')),
        Expanded(child: _Stat('Fleet', 'Shipments, drivers, vehicles')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.label);

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Color(0xFFD5DDE6), fontSize: 14, height: 1.25)),
      ],
    );
  }
}
