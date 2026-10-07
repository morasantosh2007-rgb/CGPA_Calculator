import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../navigation/main_nav_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _deptController = TextEditingController();
  final _yearController = TextEditingController(text: '3rd Year (B.Tech)');
  final _uniController = TextEditingController(text: 'National Institute of Technology Andhra Pradesh');
  final _emailController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _regNoController.dispose();
    _rollNoController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    _uniController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _fillMoraSantoshPreset() {
    setState(() {
      _nameController.text = 'MORA SANTOSH';
      _regNoController.text = '424154';
      _rollNoController.text = '424154';
      _deptController.text = 'Computer Science & Engineering';
      _yearController.text = '3rd Year (B.Tech)';
      _uniController.text = 'National Institute of Technology Andhra Pradesh';
      _emailController.text = '424154@student.nitandhra.ac.in';
    });
  }

  Future<void> _submitSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'full_name': _nameController.text.trim(),
        'registration_number': _regNoController.text.trim(),
        'roll_number': _rollNoController.text.trim().isNotEmpty
            ? _rollNoController.text.trim()
            : _regNoController.text.trim(),
        'department': _deptController.text.trim(),
        'academic_year': _yearController.text.trim(),
        'university_name': _uniController.text.trim(),
        'institute_email': _emailController.text.trim(),
      };

      final response = await ApiClient.dio.post(ApiConstants.studentSetup, data: payload);

      if (response.data != null && response.data['id'] != null) {
        final studentId = response.data['id'].toString();
        final regNo = response.data['registration_number']?.toString() ?? _regNoController.text.trim();
        final name = response.data['full_name']?.toString() ?? _nameController.text.trim();

        await ApiClient.saveStudentSession(
          studentId: studentId,
          regNo: regNo,
          fullName: name,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, $name! Your academic profile is active.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavScaffold()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: $e. Please verify details and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school, size: 48, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Welcome to GradeLens',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Set up your student profile to track your semesters, calculate SGPA & CGPA, and analyze academic standing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preset shortcut
                    OutlinedButton.icon(
                      onPressed: _fillMoraSantoshPreset,
                      icon: const Icon(Icons.flash_on, color: Color(0xFF2563EB), size: 18),
                      label: const Text('Quick Fill Mora Santosh (424154)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. MORA SANTOSH',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: 14),

                    // Registration Number & Roll Number
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _regNoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Registration No *',
                              hintText: 'e.g. 424154',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rollNoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Roll Number',
                              hintText: 'e.g. 424154',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Department / Branch
                    TextFormField(
                      controller: _deptController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Department / Branch *',
                        hintText: 'e.g. Computer Science & Engineering',
                        prefixIcon: const Icon(Icons.account_tree_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your department' : null,
                    ),
                    const SizedBox(height: 14),

                    // Academic Year / Current Standing
                    TextFormField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        labelText: 'Academic Year / Class *',
                        hintText: 'e.g. 3rd Year (B.Tech)',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please specify academic year' : null,
                    ),
                    const SizedBox(height: 14),

                    // University / Institute Name
                    TextFormField(
                      controller: _uniController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Institute / University *',
                        hintText: 'e.g. National Institute of Technology Andhra Pradesh',
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter institute name' : null,
                    ),
                    const SizedBox(height: 14),

                    // Institute Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Institute Email *',
                        hintText: 'e.g. 424154@student.nitandhra.ac.in',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your institute email';
                        if (!val.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Profile & Enter GradeLens',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Your profile is securely isolated to this device.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
