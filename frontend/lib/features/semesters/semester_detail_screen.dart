import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/file_download_helper.dart';

class SemesterDetailScreen extends StatefulWidget {
  final String semesterId;
  final int semesterNumber;

  const SemesterDetailScreen({
    super.key,
    required this.semesterId,
    required this.semesterNumber,
  });

  @override
  State<SemesterDetailScreen> createState() => _SemesterDetailScreenState();
}

class _SemesterDetailScreenState extends State<SemesterDetailScreen> {
  Map<String, dynamic>? _semesterData;
  List _attempts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSemesterDetail();
  }

  Future<void> _fetchSemesterDetail() async {
    setState(() => _isLoading = true);
    try {
      final semRes = await ApiClient.dio.get('${ApiConstants.semesters}${widget.semesterId}/');
      final attRes = await ApiClient.dio.get('${ApiConstants.semesters}${widget.semesterId}/attempts/');

      List rawAttempts = [];
      if (attRes.data is Map) {
        rawAttempts = attRes.data['results'] as List? ?? [];
      } else if (attRes.data is List) {
        rawAttempts = attRes.data as List;
      }

      setState(() {
        _semesterData = semRes.data is Map ? semRes.data as Map<String, dynamic> : null;
        _attempts = rawAttempts;
      });
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'EX':
      case 'O':
        return const Color(0xFF6366F1);
      case 'A':
        return const Color(0xFF2563EB);
      case 'B':
        return const Color(0xFF0D9488);
      case 'C':
        return const Color(0xFFD97706);
      case 'D':
        return const Color(0xFFEA580C);
      case 'P':
        return const Color(0xFF10B981);
      case 'F':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Semester ${widget.semesterNumber}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sgpa = _semesterData?['sgpa'];
    final totalCredits = _semesterData?['total_credits'] ?? 0.0;
    final subjects = (_semesterData?['effective_subjects'] as List?) ?? [];
    final academicYear = _semesterData?['academic_year'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Semester ${widget.semesterNumber} Detail', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSemesterDetail,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Summary Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SEMESTER ${widget.semesterNumber}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (academicYear.toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$academicYear',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Reconciled SGPA', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            sgpa != null ? (sgpa as num).toStringAsFixed(2) : '--',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 48, width: 1, color: Colors.white24),
                      Column(
                        children: [
                          const Text('Total Earned Credits', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            (totalCredits as num).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 2. Effective Reconciled Course List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Effective Reconciled Subjects (${subjects.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Reconciled Best Standing',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (subjects.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No individual subjects reconciled yet.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjects.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
                  itemBuilder: (context, idx) {
                    final subj = subjects[idx];
                    final code = subj['subject_code'] ?? '';
                    final name = subj['subject_name'] ?? '';
                    final grade = (subj['grade'] ?? '').toString();
                    final gp = ((subj['grade_point'] as num?)?.toDouble()) ?? 0.0;
                    final credits = ((subj['credits'] as num?)?.toDouble()) ?? 0.0;
                    final isPass = subj['is_pass'] == true;
                    final gradeColor = _getGradeColor(grade);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: gradeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: gradeColor.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          grade,
                          style: TextStyle(
                            color: gradeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                code,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${credits.toStringAsFixed(1)} Credits • GP: ${gp.toStringAsFixed(1)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPass ? 'PASS' : 'FAIL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPass ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 28),

            // 3. Examination Attempts Timeline
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Examination Attempts & Sittings (${_attempts.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Full Audit Trail',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            for (var att in _attempts) ...[
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                att['exam_type'] == 'REGULAR'
                                    ? Icons.assignment_outlined
                                    : att['exam_type'] == 'REVALUATION'
                                        ? Icons.rate_review_outlined
                                        : Icons.replay_outlined,
                                color: att['exam_type'] == 'REGULAR'
                                    ? const Color(0xFF2563EB)
                                    : att['exam_type'] == 'REVALUATION'
                                        ? const Color(0xFF8B5CF6)
                                        : Colors.amber.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${att['exam_type']} Examination (Attempt ${att['attempt_number']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          if (att['is_verified'] == true)
                            const Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('Verified', style: TextStyle(fontSize: 10, color: Color(0xFF166534))),
                              backgroundColor: Color(0xFFDCFCE7),
                            ),
                        ],
                      ),
                      if (att['academic_session'] != null && (att['academic_session'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Session: ${att['academic_session']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        'Subjects recorded in this sitting: ${att['subject_attempts_count']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (att['gradesheet_file_url'] != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            final rawUrl = att['gradesheet_file_url'] as String;
                            final fullUrl = rawUrl.startsWith('http')
                                ? rawUrl
                                : 'http://127.0.0.1:8000$rawUrl';
                            FileDownloadHelper.openOrDownloadUrl(fullUrl);
                          },
                          icon: Icon(
                            (att['gradesheet_filename'] ?? '').toString().toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            size: 16,
                            color: (att['gradesheet_filename'] ?? '').toString().toLowerCase().endsWith('.pdf')
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          label: Text(
                            'View / Download Document (${att['gradesheet_filename'] ?? 'File'})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
