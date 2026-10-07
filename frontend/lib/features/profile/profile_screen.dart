import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get(ApiConstants.profile);
      setState(() => _profile = res.data);
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recalculateAll() async {
    setState(() => _isRecalculating = true);
    try {
      await ApiClient.dio.post(ApiConstants.recalculate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All semesters and cumulative standing successfully recalculated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      await _fetchProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _profile?['full_name'] ?? '');
    final regCtrl = TextEditingController(text: _profile?['registration_number'] ?? '');
    final rollCtrl = TextEditingController(text: _profile?['roll_number'] ?? '');
    final deptCtrl = TextEditingController(text: _profile?['department'] ?? '');
    final yearCtrl = TextEditingController(text: _profile?['academic_year'] ?? '');
    final uniCtrl = TextEditingController(text: _profile?['university_name'] ?? '');
    final emailCtrl = TextEditingController(text: _profile?['institute_email'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Academic Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: regCtrl,
                decoration: const InputDecoration(labelText: 'Registration Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rollCtrl,
                decoration: const InputDecoration(labelText: 'Roll Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department / Branch'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(labelText: 'Academic Year'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: uniCtrl,
                decoration: const InputDecoration(labelText: 'Institute / University'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Institute Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final payload = {
                  'full_name': nameCtrl.text.trim(),
                  'registration_number': regCtrl.text.trim(),
                  'roll_number': rollCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'academic_year': yearCtrl.text.trim(),
                  'university_name': uniCtrl.text.trim(),
                  'institute_email': emailCtrl.text.trim(),
                };
                final res = await ApiClient.dio.patch(ApiConstants.profile, data: payload);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  setState(() => _profile = res.data);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Academic profile updated successfully!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchProfileOrReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch or Setup Student Profile?'),
        content: const Text(
          'This will disconnect this device from the current profile and allow you to set up or log into another student profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Switch Profile'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.clearStudentSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _profile?['full_name'] ?? 'MORA SANTOSH';
    final regNo = _profile?['registration_number'] ?? '424154';
    final rollNo = _profile?['roll_number'] ?? regNo;
    final dept = _profile?['department'] ?? 'Computer Science & Engineering';
    final year = _profile?['academic_year'] ?? '3rd Year (B.Tech)';
    final instituteEmail = _profile?['institute_email'] ?? '424154@student.nitandhra.ac.in';
    final uniName = _profile?['university_name'] ?? 'National Institute of Technology Andhra Pradesh';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Identity Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reg No: $regNo',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          uniName,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Academic & Personal Details Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Academic Credentials & Info',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.person_outline,
                      label: 'Student Name',
                      value: name,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Registration Number',
                      value: regNo,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.tag,
                      label: 'Roll Number',
                      value: rollNo.isNotEmpty ? rollNo : regNo,
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.account_tree_outlined,
                      label: 'Department / Branch',
                      value: dept.isNotEmpty ? dept : 'Not Specified',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Academic Year / Class',
                      value: year.isNotEmpty ? year : 'Not Specified',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Institute Email',
                      value: instituteEmail.isNotEmpty ? instituteEmail : 'Not Specified',
                    ),
                    const Divider(height: 1),
                    _buildInfoTile(
                      icon: Icons.account_balance_outlined,
                      label: 'Institute / University',
                      value: uniName.isNotEmpty ? uniName : 'Not Specified',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Academic Sync & Device Profile Actions
            ElevatedButton.icon(
              onPressed: _isRecalculating ? null : _recalculateAll,
              icon: const Icon(Icons.sync),
              label: _isRecalculating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Recalculate All Semesters & CGPA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _switchProfileOrReset,
              icon: const Icon(Icons.swap_horiz, color: Colors.blueGrey),
              label: const Text('Switch Student Profile / Setup New Student', style: TextStyle(color: Colors.blueGrey)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
