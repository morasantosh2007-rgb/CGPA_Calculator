import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../verification/verification_screen.dart';

/// Representation of a document selected for ingestion across Web, Desktop, and Mobile.
class UploadItem {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

  UploadItem({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<UploadItem> _selectedFiles = [];
  bool _isUploading = false;
  String _uploadStatusMessage = '';
  double _uploadProgress = 0.0;

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
            path: picked.path,
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
        withData: true, // Crucial for Flutter Web and cross-platform byte access
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            // Avoid adding duplicates by name and size
            final isDuplicate = _selectedFiles.any(
              (item) => item.name == f.name && item.size == f.size,
            );
            if (!isDuplicate) {
              _selectedFiles.add(UploadItem(
                name: f.name,
                size: f.size,
                bytes: f.bytes,
                path: f.path,
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

      MultipartFile multipartFile;
      if (item.bytes != null) {
        multipartFile = MultipartFile.fromBytes(
          item.bytes!,
          filename: item.name,
        );
      } else if (item.path != null) {
        multipartFile = await MultipartFile.fromFile(
          item.path!,
          filename: item.name,
        );
      } else {
        throw Exception('Selected file contains no readable data.');
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      setState(() {
        _uploadProgress = 0.45;
        _uploadStatusMessage = 'Reading document structure and heading metadata...';
      });

      final response = await ApiClient.dio.post(
        ApiConstants.uploadGradeSheet,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = 0.2 + (sent / total) * 0.3;
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
      final subjects = summary['subjects'] as List? ?? [];

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              gradeSheetId: sheetData['id'],
              detectedSemester: sheetData['detected_semester'] ?? 1,
              detectedExamType: sheetData['detected_exam_type'] ?? 'REGULAR',
              rawSubjects: subjects,
              studentMatch: sheetData['student_match_verified'] ?? true,
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final errorMsg = e.response?.data?['error'] ?? 'Upload failed. Please check the document format.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
        title: const Text('Upload Grade Sheets', style: TextStyle(fontWeight: FontWeight.bold)),
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
                color: const Color(0xFF2563EB).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload PDFs, photos, or scanned grade sheets. GradeLens automatically reads header metadata, identifies the semester and attempt type (Regular/Supplementary), and links backlog results.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                    color: Colors.grey.withOpacity(0.04),
                    border: Border.all(color: Colors.grey.withOpacity(0.25), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 44, color: theme.colorScheme.primary.withOpacity(0.6)),
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
              color: Colors.black.withOpacity(0.02),
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
