import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analytics_data.dart';
import '../models/transaction_category.dart';

/// Interactive pie chart for category breakdown
class CategoryPieChart extends StatefulWidget {
  final List<CategoryAnalytics> categories;
  final double size;
  final bool showLegend;

  const CategoryPieChart({
    super.key,
    required this.categories,
    this.size = 200,
    this.showLegend = true,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.size,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: widget.size * 0.2,
              sections: _buildPieChartSections(),
            ),
          ),
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    return widget.categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? widget.size * 0.3 : widget.size * 0.25;

      return PieChartSectionData(
        color: category.color,
        value: category.totalAmount,
        title: '${category.percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.categories.map((category) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              category.categoryName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Line chart for trends over time
class TrendsLineChart extends StatelessWidget {
  final List<AnalyticsDataPoint> dataPoints;
  final String title;
  final Color lineColor;
  final bool showIncome;
  final bool showExpenses;
  final bool showNetFlow;

  const TrendsLineChart({
    super.key,
    required this.dataPoints,
    required this.title,
    this.lineColor = Colors.blue,
    this.showIncome = true,
    this.showExpenses = true,
    this.showNetFlow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: _calculateInterval(),
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toStringAsFixed(0)} BTCZ',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < dataPoints.length) {
                        final date = dataPoints[value.toInt()].date;
                        return Text(
                          '${date.month}/${date.day}',
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              lineBarsData: _buildLineBarsData(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final dataPoint = dataPoints[barSpot.x.toInt()];
                      String label;
                      if (barSpot.barIndex == 0 && showIncome) {
                        label = 'Income: ${dataPoint.income.toStringAsFixed(2)} BTCZ';
                      } else if (barSpot.barIndex == 1 && showExpenses) {
                        label = 'Expenses: ${dataPoint.expenses.toStringAsFixed(2)} BTCZ';
                      } else if (showNetFlow) {
                        label = 'Net Flow: ${dataPoint.netFlow.toStringAsFixed(2)} BTCZ';
                      } else {
                        label = '${barSpot.y.toStringAsFixed(2)} BTCZ';
                      }
                      
                      return LineTooltipItem(
                        label,
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildLegend(),
      ],
    );
  }

  List<LineChartBarData> _buildLineBarsData() {
    final List<LineChartBarData> lineBars = [];

    if (showIncome) {
      lineBars.add(
        LineChartBarData(
          spots: dataPoints.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.income);
          }).toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withOpacity(0.1),
          ),
        ),
      );
    }

    if (showExpenses) {
      lineBars.add(
        LineChartBarData(
          spots: dataPoints.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.expenses);
          }).toList(),
          isCurved: true,
          color: Colors.red,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.red.withOpacity(0.1),
          ),
        ),
      );
    }

    if (showNetFlow) {
      lineBars.add(
        LineChartBarData(
          spots: dataPoints.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.netFlow);
          }).toList(),
          isCurved: true,
          color: lineColor,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );
    }

    return lineBars;
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIncome) ...[
          _buildLegendItem('Income', Colors.green),
          const SizedBox(width: 16),
        ],
        if (showExpenses) ...[
          _buildLegendItem('Expenses', Colors.red),
          const SizedBox(width: 16),
        ],
        if (showNetFlow) ...[
          _buildLegendItem('Net Flow', lineColor),
        ],
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  double _calculateInterval() {
    if (dataPoints.isEmpty) return 1;
    
    final maxValue = dataPoints
        .map((d) => [d.income, d.expenses, d.netFlow.abs()].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    
    return maxValue / 5; // 5 horizontal lines
  }
}

/// Bar chart for comparing categories or periods
class ComparisonBarChart extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final Color barColor;
  final bool horizontal;

  const ComparisonBarChart({
    super.key,
    required this.data,
    required this.title,
    this.barColor = Colors.blue,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: data.values.reduce((a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final key = data.keys.elementAt(groupIndex);
                    return BarTooltipItem(
                      '$key\n${rod.toY.toStringAsFixed(2)} BTCZ',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < data.length) {
                        final key = data.keys.elementAt(value.toInt());
                        return Text(
                          key.length > 8 ? '${key.substring(0, 8)}...' : key,
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              barGroups: data.entries.map((entry) {
                final index = data.keys.toList().indexOf(entry.key);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      color: barColor,
                      width: 20,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
