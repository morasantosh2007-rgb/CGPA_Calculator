import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/academic_summary.dart';
import '../simulator/simulator_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _progressionData;
  Map<String, dynamic>? _distributionData;
  AcademicSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final progRes = await ApiClient.dio.get(ApiConstants.progression);
      final distRes = await ApiClient.dio.get(ApiConstants.distribution);
      final summaryRes = await ApiClient.dio.get(ApiConstants.summary);

      setState(() {
        _progressionData = progRes.data is Map ? progRes.data as Map<String, dynamic> : null;
        _distributionData = distRes.data is Map ? distRes.data as Map<String, dynamic> : null;
        if (summaryRes.data is Map) {
          _summary = AcademicSummary.fromJson(summaryRes.data as Map<String, dynamic>);
        }
      });
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progression = (_progressionData?['progression'] as List?) ?? [];
    final dist = _distributionData ?? {};
    final cgpa = _summary?.cgpa ?? 0.0;
    final totalCredits = _summary?.totalCreditsCompleted ?? 0.0;
    final activeBacklogs = _summary?.activeBacklogsCount ?? 0;
    final highestSgpa = _summary?.highestSgpa ?? 0.0;

    // Calculate dynamic maxY for grade distribution bar chart
    final gradeKeys = ['EX', 'A', 'B', 'C', 'D', 'P', 'M', 'F'];
    final gradeColors = [
      const Color(0xFF6366F1), // EX: Indigo
      const Color(0xFF2563EB), // A: Royal Blue
      const Color(0xFF0D9488), // B: Teal
      const Color(0xFFF59E0B), // C: Amber
      const Color(0xFFEA580C), // D: Orange
      const Color(0xFF10B981), // P: Emerald
      const Color(0xFF64748B), // M: Slate
      const Color(0xFFEF4444), // F: Crimson
    ];

    double maxCount = 0.0;
    for (var g in gradeKeys) {
      final count = ((dist[g] as num?)?.toDouble()) ?? 0.0;
      if (count > maxCount) maxCount = count;
    }
    final dynamicMaxY = maxCount <= 8 ? 10.0 : (((maxCount / 5).ceil() * 5) + 5).toDouble();
    final yInterval = (dynamicMaxY / 5).roundToDouble().clamp(1.0, 50.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'What-If & Target Simulators',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SimulatorScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. KPI Overview Stats
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Overall CGPA',
                      value: cgpa > 0 ? cgpa.toStringAsFixed(2) : '--',
                      subtitle: 'Scale: 10.0',
                      icon: Icons.school_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Earned Credits',
                      value: totalCredits.toStringAsFixed(1),
                      subtitle: 'Cumulative',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Semesters Done',
                      value: '${progression.length}',
                      subtitle: highestSgpa > 0 ? 'Max SGPA: ${highestSgpa.toStringAsFixed(2)}' : 'Recorded',
                      icon: Icons.layers_outlined,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Active Backlogs',
                      value: '$activeBacklogs',
                      subtitle: activeBacklogs == 0 ? 'All Clear' : 'Attention needed',
                      icon: activeBacklogs == 0 ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
                      color: activeBacklogs == 0 ? const Color(0xFF10B981) : Colors.amber.shade800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. What-If Simulator Banner
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SimulatorScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What-If & Target CGPA Simulator',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Simulate backlog clearing and calculate required grades for graduation targets.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 3. Dual-Line Progression Trend Chart (SGPA vs Rolling CGPA)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Academic Progression Trend',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Semester SGPA vs Cumulative Rolling CGPA',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildLegendItem('Semester SGPA', const Color(0xFF2563EB)),
                  const SizedBox(width: 16),
                  _buildLegendItem('Rolling CGPA', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 20, 16),
                  child: SizedBox(
                    height: 230,
                    child: progression.isEmpty
                        ? const Center(
                            child: Text(
                              'No progression data available yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 10,
                              minX: 0,
                              maxX: max(1.0, (progression.length - 1).toDouble()),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 2,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.withOpacity(0.12),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    interval: 2,
                                    getTitlesWidget: (val, meta) => Text(
                                      val.toInt().toString(),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    reservedSize: 28,
                                    getTitlesWidget: (val, meta) {
                                      int idx = val.round();
                                      if (idx >= 0 && idx < progression.length && (val - idx).abs() < 0.01) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Sem ${progression[idx]['semester_number']}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final isSgpa = spot.barIndex == 0;
                                      final label = isSgpa ? 'SGPA' : 'CGPA';
                                      return LineTooltipItem(
                                        '$label: ${spot.y.toStringAsFixed(2)}',
                                        TextStyle(
                                          color: isSgpa ? const Color(0xFF93C5FD) : const Color(0xFF6EE7B7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                // Line 1: SGPA (Blue)
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < progression.length; i++)
                                      FlSpot(
                                        i.toDouble(),
                                        ((progression[i]['sgpa'] as num?)?.toDouble()) ?? 0.0,
                                      ),
                                  ],
                                  isCurved: true,
                                  curveSmoothness: 0.3,
                                  color: const Color(0xFF2563EB),
                                  barWidth: 3.5,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFF2563EB),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                ),
                                // Line 2: Cumulative Rolling CGPA (Emerald Green)
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < progression.length; i++)
                                      FlSpot(
                                        i.toDouble(),
                                        ((progression[i]['rolling_cgpa'] as num?)?.toDouble()) ?? 0.0,
                                      ),
                                  ],
                                  isCurved: true,
                                  curveSmoothness: 0.3,
                                  color: const Color(0xFF10B981),
                                  barWidth: 3.5,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFF10B981),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF10B981).withOpacity(0.2),
                                        const Color(0xFF10B981).withOpacity(0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 4. Grade Distribution Section (Dynamic maxY to prevent overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade Distribution (EX to F)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total frequency of letter grades across all semesters',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: dynamicMaxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: yInterval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.12),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (val, meta) {
                                int idx = val.toInt();
                                if (idx >= 0 && idx < gradeKeys.length) {
                                  final count = (dist[gradeKeys[idx]] as num?)?.toInt() ?? 0;
                                  if (count > 0) {
                                    return Text(
                                      '$count',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: gradeColors[idx],
                                      ),
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: yInterval,
                              reservedSize: 28,
                              getTitlesWidget: (val, meta) => Text(
                                val.toInt().toString(),
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                int idx = val.toInt();
                                if (idx >= 0 && idx < gradeKeys.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      gradeKeys[idx],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: gradeColors[idx],
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < gradeKeys.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: ((dist[gradeKeys[i]] as num?)?.toDouble()) ?? 0.0,
                                  color: gradeColors[i],
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                )
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 5. Semester-by-Semester Progression Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Semester-by-Semester Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${progression.length} Semesters',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              for (int i = 0; i < progression.length; i++) ...[
                _buildProgressionCard(progression[i], i > 0 ? progression[i - 1] : null),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionCard(Map<String, dynamic> current, Map<String, dynamic>? previous) {
    final semNum = current['semester_number'] ?? 0;
    final sgpa = ((current['sgpa'] as num?)?.toDouble()) ?? 0.0;
    final rollingCgpa = ((current['rolling_cgpa'] as num?)?.toDouble()) ?? 0.0;
    final credits = ((current['credits'] as num?)?.toDouble()) ?? 0.0;

    double delta = 0.0;
    bool hasDelta = false;
    if (previous != null) {
      final prevSgpa = ((previous['sgpa'] as num?)?.toDouble()) ?? 0.0;
      delta = sgpa - prevSgpa;
      hasDelta = true;
    }

    final isPositive = delta >= 0;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
              child: Text(
                'S$semNum',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Semester $semNum SGPA: ${sgpa.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (hasDelta) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 10,
                                color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${isPositive ? "+" : ""}${delta.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cumulative Rolling CGPA: ${rollingCgpa.toStringAsFixed(2)} • ${credits.toStringAsFixed(1)} Credits',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rollingCgpa.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
                const Text(
                  'Rolling CGPA',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
