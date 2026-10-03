import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/operations_math.dart';
import '../models/operations.dart';
import 'dark_page.dart';

class OutcomeChart extends StatelessWidget {
  const OutcomeChart({super.key, required this.completed, required this.failed, required this.active});

  final int completed;
  final int failed;
  final int active;

  @override
  Widget build(BuildContext context) {
    final total = completed + failed + active;
    if (total == 0) {
      return const Text('No delivery outcomes in this period.', style: TextStyle(color: DarkColors.muted));
    }
    return Column(
      children: [
        _ShareRow(label: 'Active', count: active, total: total, color: const Color(0xFF3B82F6)),
        const SizedBox(height: 10),
        _ShareRow(label: 'Completed', count: completed, total: total, color: const Color(0xFF22C55E)),
        const SizedBox(height: 10),
        _ShareRow(label: 'Failed', count: failed, total: total, color: const Color(0xFFEF4444)),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.label, required this.count, required this.total, required this.color});

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: DarkColors.line,
              color: count == 0 ? DarkColors.line : color,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key, required this.volume});

  final List<BucketCount> volume;

  @override
  Widget build(BuildContext context) {
    final points = volume.where((item) => item.count > 0).toList();
    if (points.isEmpty) {
      return const Text('No pickups in this period.', style: TextStyle(color: DarkColors.muted));
    }
    if (points.length < 2) {
      final only = points.single;
      return _FactLine(label: shortPeriod(only.period), value: _pickupLabel(only.count));
    }
    final maxCount = points.map((item) => item.count).reduce((a, b) => a > b ? a : b);
    final maxY = maxCount <= 1 ? 1.0 : maxCount.ceilToDouble();
    return SizedBox(
      height: 168,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          groupsSpace: 12,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 4 ? 1 : null,
            getDrawingHorizontalLine: (_) => const FlLine(color: DarkColors.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY <= 4 ? 1 : null,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: DarkColors.muted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final show = points.length <= 6 || index == 0 || index == points.length - 1 || index == points.length ~/ 2;
                  if (!show) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(shortPeriod(points[index].period), style: const TextStyle(color: DarkColors.muted, fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < points.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: points[index].count.toDouble(),
                    color: const Color(0xFF3B82F6),
                    width: points.length > 14 ? 8 : 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
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
    final plotted = points.where((item) => (parseAmount(item.totalCost) ?? 0) > 0).toList();
    if (plotted.isEmpty) {
      return const Text('No fuel cost in this period.', style: TextStyle(color: DarkColors.muted));
    }
    if (plotted.length < 2) {
      final only = plotted.single;
      return _FactLine(label: shortPeriod(only.period), value: formatInr(only.totalCost));
    }
    final amounts = [for (final point in plotted) (parseAmount(point.totalCost) ?? 0).toDouble()];
    final peak = amounts.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 168,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: peak <= 0 ? 1 : peak * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: DarkColors.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  final index = value.toInt();
                  if (index != 0 && index != plotted.length - 1) {
                    return const SizedBox.shrink();
                  }
                  if (index < 0 || index >= plotted.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(shortPeriod(plotted[index].period), style: const TextStyle(color: DarkColors.muted, fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: plotted.length > 2,
              color: const Color(0xFF3B82F6),
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withValues(alpha: 0.16)),
              spots: [
                for (var index = 0; index < amounts.length; index++) FlSpot(index.toDouble(), amounts[index]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w600))),
        Text(value, style: const TextStyle(color: DarkColors.muted)),
      ],
    );
  }
}

String shortPeriod(String period) {
  final parsed = DateTime.tryParse(period);
  if (parsed == null) {
    return period;
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${parsed.day} ${months[parsed.month - 1]}';
}

String formatInr(String raw) {
  final amount = parseAmount(raw);
  if (amount == null) {
    return raw;
  }
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    if (index > 0 && remaining > 3 && (remaining - 3) % 2 == 0) {
      buffer.write(',');
    } else if (index > 0 && remaining == 3) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}₹$buffer.${parts.last}';
}

String _pickupLabel(int count) {
  return count == 1 ? '1 pickup' : '$count pickups';
}
