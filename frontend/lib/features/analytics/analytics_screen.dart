import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../simulator/simulator_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _progressionData;
  Map<String, dynamic>? _distributionData;
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

      setState(() {
        _progressionData = progRes.data;
        _distributionData = distRes.data;
      });
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progression = (_progressionData?['progression'] as List?) ?? [];
    final dist = _distributionData ?? {};

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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulator Banner Shortcut
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
                  gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What-If & Target CGPA Simulator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Simulate backlog clearing and calculate required grades for graduation targets.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Grade Distribution Section
            Text('Grade Distribution (EX to F)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: 15,
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final grades = ['EX', 'A', 'B', 'C', 'D', 'P', 'M', 'F'];
                              int idx = val.toInt();
                              if (idx >= 0 && idx < grades.length) {
                                return Text(grades[idx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < 8; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: ((dist[['EX', 'A', 'B', 'C', 'D', 'P', 'M', 'F'][i]] as num?)?.toDouble()) ?? 0.0,
                                color: i == 7 ? Colors.red.shade400 : theme.colorScheme.primary,
                                width: 18,
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

            const SizedBox(height: 24),

            // SGPA Progression List
            Text('Semester-by-Semester Progression', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            for (var p in progression) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text('S${p['semester_number']}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('Semester ${p['semester_number']} SGPA: ${p['sgpa']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Rolling CGPA: ${p['rolling_cgpa']} • ${p['credits']} Credits'),
                  trailing: const Icon(Icons.trending_up, color: Colors.green),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
