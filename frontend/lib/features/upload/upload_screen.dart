import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../verification/verification_screen.dart';

/// Representation of a document selected for ingestion across Web, Desktop, and Mobile.
class UploadItem {
  final String name;
  final int size;
  final Uint8List? bytes;

  UploadItem({
    required this.name,
    required this.size,
    this.bytes,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class UploadScreen extends StatefulWidget {
  final int? preselectedSemester;
  final bool isReupload;

  const UploadScreen({
    super.key,
    this.preselectedSemester,
    this.isReupload = false,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<UploadItem> _selectedFiles = [];
  bool _isUploading = false;
  String _uploadStatusMessage = '';
  double _uploadProgress = 0.0;
  int? _targetSemester;
  bool _forceReupload = false;

  @override
  void initState() {
    super.initState();
    _targetSemester = widget.preselectedSemester;
    _forceReupload = widget.isReupload;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedFiles.add(UploadItem(
            name: picked.name,
            size: bytes.length,
            bytes: bytes,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Always loads in-memory bytes across all platforms
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            final isDuplicate = _selectedFiles.any(
              (item) => item.name == f.name && item.size == f.size,
            );
            if (!isDuplicate) {
              _selectedFiles.add(UploadItem(
                name: f.name,
                size: f.size,
                bytes: f.bytes,
              ));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStatusMessage = 'Uploading grade sheet...';
    });

    try {
      final item = _selectedFiles.first;

      if (item.bytes == null || item.bytes!.isEmpty) {
        throw Exception('Selected file "${item.name}" has no readable data.');
      }

      final ext = item.name.split('.').last.toLowerCase();
      MediaType mediaType;
      if (ext == 'pdf') {
        mediaType = MediaType('application', 'pdf');
      } else if (ext == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (ext == 'webp') {
        mediaType = MediaType('image', 'webp');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }

      final multipartFile = MultipartFile.fromBytes(
        item.bytes!,
        filename: item.name,
        contentType: mediaType,
      );

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      if (_targetSemester != null) {
        formData.fields.add(MapEntry('custom_semester', _targetSemester.toString()));
      }
      if (_forceReupload) {
        formData.fields.add(const MapEntry('is_reupload', 'true'));
      }

      setState(() {
        _uploadProgress = 0.35;
        _uploadStatusMessage = 'Uploading ${item.name} (${item.formattedSize})...';
      });

      final response = await ApiClient.dio.post(
        ApiConstants.uploadGradeSheet,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = 0.2 + (sent / total) * 0.3;
              if (sent == total) {
                _uploadStatusMessage = 'Running AI OCR & heading intelligence... (may take 20-40s for multi-page scans)';
              }
            });
          }
        },
      );

      setState(() {
        _uploadProgress = 0.85;
        _uploadStatusMessage = 'Extracting subjects, credits, and grades...';
      });

      final sheetData = response.data['gradesheet'] ?? response.data;
      final summary = response.data['extracted_summary'] ?? {};
      final semesterBlocks = summary['semester_blocks'] as List? ?? [];
      final subjects = summary['subjects'] as List? ?? [];
      final isDuplicate = response.data['is_duplicate'] == true;

      if (isDuplicate && !_forceReupload && mounted) {
        final reprocess = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('Document Already Uploaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This document matches an existing grade sheet in your profile.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Detected Semester: ${sheetData['detected_semester'] ?? 1}\n'
                    'Subjects Found: ${subjects.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Would you like to review the existing data, or force re-upload and re-analyze to replace it?',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Review Existing'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Force Re-upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (reprocess == true) {
          _forceReupload = true;
          return _uploadAndProcess();
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              gradeSheetId: sheetData['id'],
              detectedSemester: sheetData['detected_semester'] ?? 1,
              detectedExamType: sheetData['detected_exam_type'] ?? 'REGULAR',
              rawSubjects: subjects,
              studentMatch: sheetData['student_match_verified'] ?? true,
              semesterBlocks: semesterBlocks,
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMsg;
        if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
          errorMsg = 'Document processing took longer than expected. If uploading a multi-page PDF scan, please retry.';
        } else if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['error'] != null && data['error'].toString().isNotEmpty) {
            errorMsg = data['error'].toString();
          } else if (data['detail'] != null) {
            errorMsg = data['detail'].toString();
          } else if (data['file'] != null) {
            final fErr = data['file'];
            errorMsg = fErr is List ? fErr.join(', ') : fErr.toString();
          } else if (data['message'] != null) {
            errorMsg = data['message'].toString();
          } else {
            errorMsg = 'Upload failed (${e.response?.statusCode ?? 400}). Please check your document.';
          }
        } else if (e.response?.data is String && (e.response!.data as String).isNotEmpty) {
          errorMsg = 'Server response error: ${e.response?.statusCode}';
        } else {
          errorMsg = 'Upload failed: ${e.message ?? "Connection interrupted"}. Please check your connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _forceReupload && _targetSemester != null
              ? 'Re-upload Semester $_targetSemester'
              : 'Upload Grade Sheets',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload PDFs, photos, or scanned grade sheets. GradeNexus automatically reads header metadata, identifies the semester and attempt type (Regular/Supplementary), and links backlog results.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),

            if (_forceReupload) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.replay_circle_filled, color: Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Re-upload Mode Active: Replacing Grade Sheet for Semester ${_targetSemester ?? "Auto"}',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Exit Re-upload mode',
                      onPressed: () => setState(() => _forceReupload = false),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Target Semester Assignment Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target Semester',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                _targetSemester == null
                                    ? 'Auto-detect from document headers (Default)'
                                    : 'Explicitly assigned to Semester $_targetSemester',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int?>(
                          value: _targetSemester,
                          underline: const SizedBox(),
                          hint: const Text('Auto-detect', style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Auto-detect'),
                            ),
                            ...List.generate(
                              8,
                              (i) => DropdownMenuItem<int?>(
                                value: i + 1,
                                child: Text('Semester ${i + 1}'),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _targetSemester = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (!_forceReupload) ...[
                      const Divider(height: 16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _forceReupload = !_forceReupload;
                          });
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _forceReupload,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: (val) {
                                  setState(() {
                                    _forceReupload = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Force re-upload & overwrite existing data for this document',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Ingestion Options
            Row(
              children: [
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF / Files',
                    onTap: _pickFiles,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Queue List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Documents (${_selectedFiles.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_selectedFiles.isNotEmpty && !_isUploading)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedFiles.clear()),
                    icon: const Icon(Icons.clear_all, size: 18, color: Colors.grey),
                    label: const Text('Clear All', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_selectedFiles.isEmpty)
              InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.04),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.25), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 44, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                        const SizedBox(height: 10),
                        const Text(
                          'Click to select PDF or image grade sheets',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports PDF, JPG, PNG from device or portal downloads',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final fileItem = _selectedFiles[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: fileItem.isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          fileItem.isPdf ? Icons.picture_as_pdf : Icons.image,
                          color: fileItem.isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        fileItem.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${fileItem.formattedSize} • Ready for analysis',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove',
                        onPressed: _isUploading
                            ? null
                            : () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 32),

            if (_isUploading) ...[
              Center(
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress, minHeight: 6),
                    const SizedBox(height: 14),
                    Text(
                      _uploadStatusMessage,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: _selectedFiles.isEmpty || _isUploading ? null : _uploadAndProcess,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(
                _isUploading ? 'Analyzing Document...' : 'Start Document Intelligence & OCR',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF2563EB)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
