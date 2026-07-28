import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/productive_task_service.dart';
import '../utils/constants.dart';
import '../widgets/hour_cap_picker.dart';

class DailyCapSetupScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final double currentHours;

  const DailyCapSetupScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.currentHours = 2.0,
  });

  @override
  State<DailyCapSetupScreen> createState() => _DailyCapSetupScreenState();
}

class _DailyCapSetupScreenState extends State<DailyCapSetupScreen> {
  final ProductiveTaskService _service = ProductiveTaskService();
  static const List<double> _options = [1, 1.5, 2, 2.5, 3, 4];

  late double _hours;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final closest = _options.reduce(
      (a, b) =>
          (a - widget.currentHours).abs() < (b - widget.currentHours).abs()
          ? a
          : b,
    );
    _hours = _options.contains(widget.currentHours)
        ? widget.currentHours
        : closest;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _service.setChildDailyCapHours(
        parentUid: uid,
        childId: widget.childId,
        childName: widget.childName,
        hours: _hours,
      );
      if (!mounted) return;
      Navigator.pop(context, _hours);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save limit: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text(
          '${widget.childName}\'s Daily Cap',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a daily screen time cap',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.childName} can only earn screen time by completing real activities — never more than the daily cap. You can change this limit anytime.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            HourCapCard(
              hours: _hours,
              options: _options,
              onChanged: (h) => setState(() => _hours = h),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kDarkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save and start',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No screen time without earning it. No exceptions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
