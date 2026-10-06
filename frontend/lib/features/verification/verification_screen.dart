import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../navigation/main_nav_scaffold.dart';

class VerificationScreen extends StatefulWidget {
  final String gradeSheetId;
  final int detectedSemester;
  final String detectedExamType;
  final List rawSubjects;
  final bool studentMatch;

  const VerificationScreen({
    super.key,
    required this.gradeSheetId,
    required this.detectedSemester,
    required this.detectedExamType,
    required this.rawSubjects,
    required this.studentMatch,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late int _semester;
  late String _examType;
  late List<Map<String, dynamic>> _subjects;
  bool _isSaving = false;

  final List<String> _gradeOptions = ['EX', 'A', 'B', 'C', 'D', 'P', 'M', 'F'];
  final List<String> _examTypes = ['REGULAR', 'SUPPLEMENTARY', 'BACKLOG', 'REVALUATION', 'IMPROVEMENT'];

  @override
  void initState() {
    super.initState();
    _semester = widget.detectedSemester;
    _examType = widget.detectedExamType;
    _subjects = widget.rawSubjects.map((s) => Map<String, dynamic>.from(s)).toList();

    // If no subjects were parsed, seed a default template row
    if (_subjects.isEmpty) {
      _subjects.add({
        'code': 'CS301',
        'name': 'Sample Subject',
        'credits': 4.0,
        'normalized_grade': 'A',
        'confidence': 1.0,
        'needs_review': false,
      });
    }
  }

  Future<void> _commitVerification() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'semester': _semester,
        'exam_type': _examType,
        'subjects': _subjects,
      };

      await ApiClient.dio.post(
        ApiConstants.verifyGradeSheet(widget.gradeSheetId),
        data: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Academic Standing recalculated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving verification: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addSubjectRow() {
    setState(() {
      _subjects.add({
        'code': '',
        'name': 'New Course',
        'credits': 3.0,
        'normalized_grade': 'B',
        'confidence': 1.0,
        'needs_review': false,
        'user_corrected': true,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Result', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Match Warning
            if (!widget.studentMatch)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This grade sheet appears to belong to a different student registration number. Please confirm carefully before proceeding.',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Header Meta Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detected Document Metadata', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _semester,
                            decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()),
                            items: [for (int i = 1; i <= 8; i++) DropdownMenuItem(value: i, child: Text('Semester $i'))],
                            onChanged: (val) {
                              if (val != null) setState(() => _semester = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _examTypes.contains(_examType) ? _examType : 'REGULAR',
                            decoration: const InputDecoration(labelText: 'Examination Type', border: OutlineInputBorder()),
                            items: _examTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _examType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Table Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subjects & Grades Table', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addSubjectRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subject'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Subject Rows List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final sub = _subjects[idx];
                final confidence = (sub['confidence'] as num?)?.toDouble() ?? 1.0;
                final needsReview = sub['needs_review'] == true || confidence < 0.70;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: needsReview ? Colors.amber.shade700 : const Color(0xFFE2E8F0),
                      width: needsReview ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (needsReview)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  'OCR Confidence: ${(confidence * 100).toInt()}% • Verify carefully',
                                  style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            SizedBox(
                              width: 85,
                              child: TextFormField(
                                initialValue: sub['code'] ?? '',
                                decoration: const InputDecoration(labelText: 'Code', isDense: true, border: OutlineInputBorder()),
                                onChanged: (v) => sub['code'] = v,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: sub['name'] ?? '',
                                decoration: const InputDecoration(labelText: 'Subject Name', isDense: true, border: OutlineInputBorder()),
                                onChanged: (v) => sub['name'] = v,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 65,
                              child: TextFormField(
                                initialValue: sub['credits']?.toString() ?? '3.0',
                                decoration: const InputDecoration(labelText: 'Cr', isDense: true, border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => sub['credits'] = double.tryParse(v) ?? 3.0,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: DropdownButtonFormField<String>(
                                value: _gradeOptions.contains(sub['normalized_grade']) ? sub['normalized_grade'] : 'A',
                                decoration: const InputDecoration(labelText: 'Grd', isDense: true, border: OutlineInputBorder()),
                                items: _gradeOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      sub['normalized_grade'] = val;
                                      sub['needs_review'] = false;
                                      sub['user_corrected'] = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _subjects.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _commitVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm & Calculate SGPA / CGPA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
