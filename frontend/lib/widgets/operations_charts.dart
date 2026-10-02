import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/operations_math.dart';
import '../models/operations.dart';

class OutcomeChart extends StatelessWidget {
  const OutcomeChart({super.key, required this.completed, required this.failed, required this.active});

  final int completed;
  final int failed;
  final int active;

  @override
  Widget build(BuildContext context) {
    final total = completed + failed + active;
    if (total == 0) {
      return const Text('No delivery outcomes in this period.', style: TextStyle(color: Color(0xFF9AA6B8)));
    }
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            if (completed > 0)
              PieChartSectionData(
                value: completed.toDouble(),
                title: '$completed',
                color: const Color(0xFF2E7D32),
                radius: 48,
              ),
            if (failed > 0)
              PieChartSectionData(
                value: failed.toDouble(),
                title: '$failed',
                color: const Color(0xFFC62828),
                radius: 48,
              ),
            if (active > 0)
              PieChartSectionData(
                value: active.toDouble(),
                title: '$active',
                color: const Color(0xFF3B82F6),
                radius: 48,
              ),
          ],
        ),
      ),
    );
  }
}

class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key, required this.volume});

  final List<BucketCount> volume;

  @override
  Widget build(BuildContext context) {
    if (volume.isEmpty) {
      return const Text('No pickups in this period.', style: TextStyle(color: Color(0xFF9AA6B8)));
    }
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          barGroups: [
            for (var index = 0; index < volume.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(toY: volume[index].count.toDouble(), color: const Color(0xFF3B82F6), width: 10),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class FuelCostChart extends StatelessWidget {
  const FuelCostChart({super.key, required this.points});

  final List<CostPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No fuel cost in this period.', style: TextStyle(color: Color(0xFF9AA6B8)));
    }
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: false,
              color: const Color(0xFF3B82F6),
              spots: [
                for (var index = 0; index < points.length; index++)
                  FlSpot(index.toDouble(), (parseAmount(points[index].totalCost) ?? 0).toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
