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
  final List? semesterBlocks;

  const VerificationScreen({
    super.key,
    required this.gradeSheetId,
    required this.detectedSemester,
    required this.detectedExamType,
    required this.rawSubjects,
    required this.studentMatch,
    this.semesterBlocks,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late bool _isMultiSemester;
  late List<Map<String, dynamic>> _blocks;
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

    final incomingBlocks = widget.semesterBlocks;
    if (incomingBlocks != null && incomingBlocks.length > 1) {
      _isMultiSemester = true;
      _blocks = incomingBlocks.map((b) {
        final bMap = Map<String, dynamic>.from(b as Map);
        final rawSubs = bMap['subjects'] as List? ?? [];
        bMap['subjects'] = rawSubs.map((s) => Map<String, dynamic>.from(s as Map)).toList();
        return bMap;
      }).toList();
      _subjects = [];
    } else {
      _isMultiSemester = false;
      _blocks = [];
      _subjects = widget.rawSubjects.map((s) => Map<String, dynamic>.from(s as Map)).toList();

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
  }

  Future<void> _commitVerification() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = _isMultiSemester
          ? {'semester_blocks': _blocks}
          : {
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
          SnackBar(
            content: Text(
              _isMultiSemester
                  ? 'All ${_blocks.length} semester attempts verified and standing calculated!'
                  : 'Academic Standing recalculated successfully!',
            ),
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

  void _addSubjectRowToBlock(Map<String, dynamic> block) {
    setState(() {
      final subs = block['subjects'] as List<Map<String, dynamic>>;
      subs.add({
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
        title: Text(
          _isMultiSemester ? 'Review All Semesters (${_blocks.length})' : 'Review Extracted Result',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This document registration number differs from your profile. Please confirm details carefully.',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Multi-Semester Banner
            if (_isMultiSemester)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consolidated Grade Sheet Document',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GradeLens parsed ${_blocks.length} semester attempt(s) from your PDF. You can verify and adjust each semester below.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (_isMultiSemester)
              // Render each semester block
              for (int bIdx = 0; bIdx < _blocks.length; bIdx++) ...[
                _buildSemesterBlockCard(_blocks[bIdx], bIdx),
                const SizedBox(height: 18),
              ]
            else ...[
              // Single semester metadata card
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
                              initialValue: _semester,
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
                              initialValue: _examTypes.contains(_examType) ? _examType : 'REGULAR',
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

              _buildSubjectsList(_subjects),
            ],

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
                  : Text(
                      _isMultiSemester
                          ? 'Confirm All ${_blocks.length} Semesters & Calculate CGPA'
                          : 'Confirm & Calculate SGPA / CGPA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterBlockCard(Map<String, dynamic> block, int blockIndex) {
    final subs = block['subjects'] as List<Map<String, dynamic>>;
    final semNum = block['semester'] as int? ?? 1;
    final examType = block['exam_type'] as String? ?? 'REGULAR';
    final pageNum = block['page_number'] ?? (blockIndex + 1);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: examType == 'REGULAR' ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Page $pageNum',
                        style: TextStyle(
                          color: examType == 'REGULAR' ? const Color(0xFF1E3A8A) : const Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Semester $semNum ($examType)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _addSubjectRowToBlock(block),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Course', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Controls for this block
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: semNum,
                    decoration: const InputDecoration(labelText: 'Semester', isDense: true, border: OutlineInputBorder()),
                    items: [for (int i = 1; i <= 8; i++) DropdownMenuItem(value: i, child: Text('Semester $i'))],
                    onChanged: (val) {
                      if (val != null) setState(() => block['semester'] = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _examTypes.contains(examType) ? examType : 'REGULAR',
                    decoration: const InputDecoration(labelText: 'Attempt Type', isDense: true, border: OutlineInputBorder()),
                    items: _examTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => block['exam_type'] = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),

            // Table of subjects for this block
            _buildSubjectsList(subs),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsList(List<Map<String, dynamic>> subjectList) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjectList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final sub = subjectList[idx];
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
            padding: const EdgeInsets.all(12),
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
                      width: 80,
                      child: TextFormField(
                        initialValue: sub['code'] ?? '',
                        decoration: const InputDecoration(labelText: 'Code', isDense: true, border: OutlineInputBorder()),
                        onChanged: (v) => sub['code'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: sub['name'] ?? '',
                        decoration: const InputDecoration(labelText: 'Subject Name', isDense: true, border: OutlineInputBorder()),
                        onChanged: (v) => sub['name'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: sub['credits']?.toString() ?? '3.0',
                        decoration: const InputDecoration(labelText: 'Cr', isDense: true, border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => sub['credits'] = double.tryParse(v) ?? 3.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: DropdownButtonFormField<String>(
                        initialValue: _gradeOptions.contains(sub['normalized_grade']) ? sub['normalized_grade'] : 'A',
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
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          subjectList.removeAt(idx);
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
    );
  }
}
