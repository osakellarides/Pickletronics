import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'session_parser.dart';

class SessionDetailsPage extends StatelessWidget {
  final Session session;
  final int displayedSessionNumber;

  const SessionDetailsPage({Key? key, required this.session, required this.displayedSessionNumber})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(197, 251, 251, 252),
        automaticallyImplyLeading: true,
        centerTitle: true,
        titleSpacing: 0,
        title: Transform.translate(
          offset: const Offset(-40, 0),
          child: Image.asset(
            'assets/pickletronics_banner.png',
            height: 175,
            fit: BoxFit.fitHeight,
          ),
        ),
      ),
      body: ListView(
        children: [
          // Session Header
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Text(
              "Session $displayedSessionNumber Details",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          // Swing Cards (formerly Impact Cards)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: session.impacts.asMap().entries.map((entry) {
                int index = entry.key + 1;
                Impact impact = entry.value;
                return ImpactCardWithGraph(
                  impact: impact,
                  impactNumber: index,
                  isSweetSpot: impact.isSweetSpot,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ImpactCardWithGraph extends StatelessWidget {
  final Impact impact;
  final int impactNumber;
  final bool isSweetSpot;

  const ImpactCardWithGraph({
    Key? key,
    required this.impact,
    required this.impactNumber,
    required this.isSweetSpot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color indicatorColor = isSweetSpot ? Colors.green.shade700 : Colors.red.shade700;
    final String indicatorText = isSweetSpot ? 'Sweet Spot Hit' : 'Off-Center Hit';
    final IconData indicatorIcon = isSweetSpot ? Icons.check_circle : Icons.cancel;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Swing Number
            Text(
              "Swing $impactNumber",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            // Stats Row - Values above the graph
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactStatColumn(
                  impact.impactStrength.toStringAsFixed(1),
                  'Swing Strength',
                  Colors.blue.shade400,
                ),
                _buildCompactStatColumn(
                  '${impact.impactRotation.toStringAsFixed(1)} °/s',
                  'Swing Rotation',
                  Colors.blue.shade400,
                ),
                _buildCompactStatColumn(
                  '${impact.maxRotation.toStringAsFixed(1)} °/s',
                  'Max Rotation',
                  Colors.blue.shade400,
                ),
              ],
            ),
            // Sweet Spot indicator
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Use the variables defined above based on isSweetSpot
                    Icon(indicatorIcon, color: indicatorColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      indicatorText, // Use the determined text
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: indicatorColor, // Use the determined color
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ImpactGraph widget with fixed graph height (chart remains 220)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ImpactGraph(
                data: impact.impactArray,
                title: 'Impact Reverberation',
                impactStrength: impact.impactStrength,
                impactRotation: impact.impactRotation,
                maxRotation: impact.maxRotation,
                isSweetSpot: isSweetSpot,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatColumn(String value, String label, Color textColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600] ?? Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ImpactGraph extends StatelessWidget {
  final List<double> data;
  final String title;
  final Color color;
  final double impactStrength;
  final double impactRotation;
  final double maxRotation;
  final bool isSweetSpot;

  const ImpactGraph({
    Key? key,
    required this.data,
    required this.title,
    this.color = Colors.blue,
    this.impactStrength = 0.0,
    this.impactRotation = 0.0,
    this.maxRotation = 0.0,
    required this.isSweetSpot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate chart spots from data
    final spots = List.generate(
      data.length,
          (i) => FlSpot(i.toDouble(), data[i]),
    );

    // If there's no data, show a placeholder message
    if (spots.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Calculate y-axis bounds
    double yMin = spots.first.y;
    double yMax = spots.first.y;
    for (final spot in spots) {
      if (spot.y < yMin) yMin = spot.y;
      if (spot.y > yMax) yMax = spot.y;
    }
    final double range = math.max(1, (yMax - yMin));
    final double margin = range * 0.1;
    final double minY = math.max(0, yMin - margin);
    final double maxY = yMax + margin;

    // Create the chart widget
    final lineChart = LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: color.withOpacity(0.8),
            // Using tooltipBgColor instead of getTooltipColor
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 25,
          horizontalInterval: range / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300] ?? Colors.grey,
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[300] ?? Colors.grey,
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[600] ?? Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: range / 4,
              getTitlesWidget: (value, meta) {
                if (value == minY || value % (range / 2) < 0.1 ||
                    value == maxY || value == 0) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[600] ?? Colors.grey,
                      fontSize: 11,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: spots.isNotEmpty ? spots.last.x : 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.blue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );

    // Build the graph widget with a fixed chart height of 220
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        SizedBox(height: 220, child: lineChart),
      ],
    );
  }
}