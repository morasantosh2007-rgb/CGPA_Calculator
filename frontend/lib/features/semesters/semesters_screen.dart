import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/file_download_helper.dart';
import '../../models/semester_model.dart';
import 'semester_detail_screen.dart';
import '../upload/upload_screen.dart';

class SemestersScreen extends StatefulWidget {
  const SemestersScreen({super.key});

  @override
  State<SemestersScreen> createState() => _SemestersScreenState();
}

class _SemestersScreenState extends State<SemestersScreen> {
  List<SemesterModel> _semesters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSemesters();
  }

  Future<void> _fetchSemesters() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get(ApiConstants.semesters);
      List rawList = [];
      if (res.data is Map) {
        rawList = res.data['results'] as List? ?? [];
      } else if (res.data is List) {
        rawList = res.data as List;
      }
      setState(() {
        _semesters = rawList.map((s) => SemesterModel.fromJson(s as Map<String, dynamic>)).toList();
        _semesters.sort((a, b) => a.semesterNumber.compareTo(b.semesterNumber));
      });
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSemester(SemesterModel sem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Semester ${sem.semesterNumber}?'),
        content: Text(
          'Are you sure you want to delete Semester ${sem.semesterNumber}?\n\n'
          'This will permanently remove this semester, its attempts, and all associated subjects. '
          'Your overall cumulative CGPA and academic standing will be automatically recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Semester'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiClient.dio.delete('${ApiConstants.semesters}${sem.id}/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Semester ${sem.semesterNumber} deleted and CGPA recalculated.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchSemesters();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete semester: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadTranscriptPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading official verified transcript PDF...')),
    );
    await FileDownloadHelper.openOrDownloadUrl(ApiConstants.exportPdf);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semesters & Attempts', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download Official Transcript PDF',
            onPressed: _downloadTranscriptPdf,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchSemesters),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _semesters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text('No semesters available yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Upload your first grade sheet to see semester records.', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _semesters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final sem = _semesters[index];
                    final sgpaStr = sem.sgpa != null ? sem.sgpa!.toStringAsFixed(2) : 'Pending';
                    final hasBacklogs = sem.status == 'BACKLOGS_PENDING';

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SemesterDetailScreen(semesterId: sem.id, semesterNumber: sem.semesterNumber),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Semester ${sem.semesterNumber}',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: hasBacklogs ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      hasBacklogs ? 'Backlogs Pending' : 'Completed',
                                      style: TextStyle(
                                        color: hasBacklogs ? Colors.amber.shade900 : Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.upload_file_outlined, size: 20),
                                    tooltip: 'Re-upload Grade Sheet for Sem ${sem.semesterNumber}',
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => UploadScreen(
                                            preselectedSemester: sem.semesterNumber,
                                            isReupload: true,
                                          ),
                                        ),
                                      ).then((_) => _fetchSemesters());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: 'Delete Semester ${sem.semesterNumber}',
                                    onPressed: () => _deleteSemester(sem),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Final SGPA', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(
                                        sgpaStr,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Credits', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text('${sem.totalCredits.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Subjects', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text('${sem.effectiveSubjectsCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => UploadScreen(
                                            preselectedSemester: sem.semesterNumber,
                                            isReupload: true,
                                          ),
                                        ),
                                      ).then((_) => _fetchSemesters());
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Re-upload Sheet', style: TextStyle(fontSize: 12)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _deleteSemester(sem),
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                    label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SemesterDetailScreen(semesterId: sem.id, semesterNumber: sem.semesterNumber),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                    label: const Text('View Details', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
