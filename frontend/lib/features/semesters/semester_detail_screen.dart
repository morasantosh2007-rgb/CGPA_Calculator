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

      setState(() {
        _semesterData = semRes.data;
        _attempts = attRes.data as List? ?? [];
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
      return Scaffold(
        appBar: AppBar(title: Text('Semester ${widget.semesterNumber}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sgpa = _semesterData?['sgpa'];
    final totalCredits = _semesterData?['total_credits'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Semester ${widget.semesterNumber} History', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Final Reconciled SGPA', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        sgpa != null ? (sgpa as num).toStringAsFixed(2) : 'N/A',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.3)),
                  Column(
                    children: [
                      const Text('Total Earned Credits', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${(totalCredits as num).toInt()}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Examination Attempts Timeline
            Text(
              'Examination Attempts (${_attempts.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            for (var att in _attempts) ...[
              Card(
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
                                att['exam_type'] == 'REGULAR' ? Icons.assignment_outlined : Icons.replay_outlined,
                                color: att['exam_type'] == 'REGULAR' ? theme.colorScheme.primary : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${att['exam_type']} Examination (Attempt ${att['attempt_number']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          if (att['is_verified'] == true)
                            const Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('Verified', style: TextStyle(fontSize: 10, color: Colors.green)),
                              backgroundColor: Color(0xFFDCFCE7),
                            ),
                        ],
                      ),
                      if (att['academic_session'] != null && (att['academic_session'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Session: ${att['academic_session']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      Text(
                        'Subjects recorded in this sitting: ${att['subject_attempts_count']}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
