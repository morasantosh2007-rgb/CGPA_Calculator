import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final _targetCgpaController = TextEditingController(text: '8.80');
  final _remainingCreditsController = TextEditingController(text: '30');

  bool _isCalculatingTarget = false;
  Map<String, dynamic>? _targetResult;

  Future<void> _calculateTarget() async {
    setState(() {
      _isCalculatingTarget = true;
      _targetResult = null;
    });

    try {
      final res = await ApiClient.dio.post(
        ApiConstants.target,
        data: {
          'target_cgpa': double.tryParse(_targetCgpaController.text) ?? 8.5,
          'remaining_credits': double.tryParse(_remainingCreditsController.text) ?? 20,
        },
      );
      setState(() => _targetResult = res.data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calculation error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingTarget = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Simulators', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target CGPA Solver Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Target CGPA Achievability Solver', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Determine the exact grade point required across future remaining courses to hit your graduation CGPA goal.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetCgpaController,
                            decoration: const InputDecoration(labelText: 'Target CGPA (e.g. 9.0)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _remainingCreditsController,
                            decoration: const InputDecoration(labelText: 'Remaining Credits', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isCalculatingTarget ? null : _calculateTarget,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isCalculatingTarget
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Calculate Required GPA'),
                    ),
                    if (_targetResult != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _targetResult!['is_achievable'] == true
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _targetResult!['is_achievable'] == true ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _targetResult!['is_achievable'] == true ? Icons.check_circle : Icons.cancel,
                                  color: _targetResult!['is_achievable'] == true ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _targetResult!['is_achievable'] == true
                                      ? 'Mathematically Achievable'
                                      : 'Target Unachievable Under Current Scale',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _targetResult!['is_achievable'] == true ? Colors.green.shade900 : Colors.red.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_targetResult!['message'] ?? '', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(
                              'Required Average Grade Point: ${_targetResult!['required_average_grade_point']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
