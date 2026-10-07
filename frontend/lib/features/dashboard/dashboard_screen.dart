import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/academic_summary.dart';
import '../../models/semester_model.dart';
import '../upload/upload_screen.dart';
import '../semesters/semester_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AcademicSummary? _summary;
  List<SemesterModel> _semesters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final summaryRes = await ApiClient.dio.get(ApiConstants.summary);
      final semRes = await ApiClient.dio.get(ApiConstants.semesters);

      List rawList = [];
      if (semRes.data is Map) {
        rawList = semRes.data['results'] as List? ?? [];
      } else if (semRes.data is List) {
        rawList = semRes.data as List;
      }

      List<SemesterModel> parsedSemesters =
          rawList.map((s) => SemesterModel.fromJson(s as Map<String, dynamic>)).toList();
      parsedSemesters.sort((a, b) => a.semesterNumber.compareTo(b.semesterNumber));

      AcademicSummary parsedSummary = AcademicSummary.fromJson(summaryRes.data);

      // Auto-trigger recalculate if semesters exist but summary is uncomputed
      if ((parsedSummary.cgpa == 0.0 || parsedSummary.totalCreditsCompleted == 0.0) &&
          parsedSemesters.isNotEmpty) {
        try {
          final recalcRes = await ApiClient.dio.post(ApiConstants.recalculate);
          if (recalcRes.data != null && recalcRes.data['summary'] != null) {
            parsedSummary = AcademicSummary.fromJson(recalcRes.data['summary']);
          }
        } catch (_) {}
      }

      setState(() {
        _summary = parsedSummary;
        _semesters = parsedSemesters;
      });
    } catch (e) {
      // Gracefully fallback
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

    final cgpa = _summary?.cgpa ?? 0.0;
    final totalCredits = _summary?.totalCreditsCompleted ?? 0.0;
    final backlogs = _summary?.activeBacklogsCount ?? 0;
    final highestSgpa = _summary?.highestSgpa ?? 0.0;
    final lowestSgpa = _summary?.lowestSgpa ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GradeLens Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Cumulative CGPA Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CUMULATIVE CGPA',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: backlogs == 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                : Colors.amber.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: backlogs == 0
                                  ? const Color(0xFF6EE7B7)
                                  : Colors.amberAccent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                backlogs == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                backlogs == 0 ? 'All Clear (0 Backlogs)' : '$backlogs Active Backlog(s)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          cgpa > 0 ? cgpa.toStringAsFixed(2) : '--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '/ 10.0',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _summary?.studentName.isNotEmpty == true
                          ? '${_summary!.studentName} • Roll/Reg: ${_summary!.registrationNumber}'
                          : 'Student Academic Standing',
                      style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Total Semesters',
                      value: '${_semesters.length}',
                      subtitle: _semesters.isNotEmpty ? 'Sem 1 - Sem ${_semesters.last.semesterNumber}' : 'None',
                      icon: Icons.layers_outlined,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Earned Credits',
                      value: totalCredits.toStringAsFixed(1),
                      subtitle: 'Cumulative',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Highest SGPA',
                      value: highestSgpa > 0 ? highestSgpa.toStringAsFixed(2) : '--',
                      subtitle: lowestSgpa > 0 ? 'Min: ${lowestSgpa.toStringAsFixed(2)}' : 'Single attempt',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 3. Semester Progression Chart Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Semester Performance Trend',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_semesters.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_semesters.length} Semesters Recorded',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 20, 16),
                  child: SizedBox(
                    height: 220,
                    child: _semesters.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.show_chart, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'Upload grade sheets to visualize your SGPA trajectory.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 10,
                              minX: 0,
                              maxX: (_semesters.length - 1).toDouble().clamp(0, 10),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 2,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.withValues(alpha: 0.12),
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
                                      if (idx >= 0 && idx < _semesters.length && (val - idx).abs() < 0.01) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Sem ${_semesters[idx].semesterNumber}',
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
                                      final idx = spot.x.round();
                                      final semNum = idx < _semesters.length ? _semesters[idx].semesterNumber : idx + 1;
                                      return LineTooltipItem(
                                        'Sem $semNum: ${spot.y.toStringAsFixed(2)} SGPA',
                                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < _semesters.length; i++)
                                      FlSpot(i.toDouble(), _semesters[i].sgpa ?? 0.0),
                                  ],
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  color: const Color(0xFF2563EB),
                                  barWidth: 3.5,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                      radius: 4.5,
                                      color: const Color(0xFF2563EB),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF2563EB).withValues(alpha: 0.25),
                                        const Color(0xFF2563EB).withValues(alpha: 0.0),
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

              // 4. Semester-Wise Breakdown
              if (_semesters.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Semesters & SGPA Overview',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_semesters.length} Semesters',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _semesters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final sem = _semesters[index];
                    final sgpaStr = sem.sgpa != null ? sem.sgpa!.toStringAsFixed(2) : 'Pending';
                    final hasBacklogs = sem.status == 'BACKLOGS_PENDING';

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SemesterDetailScreen(
                              semesterId: sem.id,
                              semesterNumber: sem.semesterNumber,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                child: Text(
                                  'S${sem.semesterNumber}',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
                                          'Semester ${sem.semesterNumber}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: hasBacklogs
                                                ? Colors.amber.withValues(alpha: 0.15)
                                                : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            hasBacklogs ? 'Backlogs' : 'Passed',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: hasBacklogs ? Colors.amber.shade900 : Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${sem.totalCredits.toStringAsFixed(1)} Credits • ${sem.effectiveSubjectsCount} Subjects',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    sgpaStr,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const Text(
                                    'SGPA',
                                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // 5. Action Banner
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  );
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Upload New Grade Sheet (Photo / Scan / PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
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
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
