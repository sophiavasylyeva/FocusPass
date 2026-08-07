import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/productive_task.dart';
import '../services/productive_task_service.dart';
import '../utils/constants.dart';
import '../widgets/tier_chip.dart';
import '../widgets/preset_card.dart';

class AssignTaskScreen extends StatefulWidget {
  final String childName;

  const AssignTaskScreen({super.key, required this.childName});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final ProductiveTaskService _taskService = ProductiveTaskService();
  String _tierFilter = 'ALL';
  bool _isSubmitting = false;

  static const List<String> _tiers = ['XS', 'S', 'M', 'L', 'XL'];

  List<ProductiveTaskPreset> get _filteredPresets {
    if (_tierFilter == 'ALL') return kProductivePresets;
    return kProductivePresets.where((p) => p.tier == _tierFilter).toList();
  }

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  Future<void> _assign({
    required String title,
    required String emoji,
    required String tier,
    required String category,
    required int minutes,
    bool isCustom = false,
    String? note,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final parentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final task = ProductiveTask(
        id: ProductiveTaskService.generateTaskId(widget.childName),
        childName: widget.childName,
        parentUid: parentUid,
        title: title,
        emoji: emoji,
        tier: tier,
        category: category,
        proposedMinutes: minutes,
        isCustom: isCustom,
        note: note,
        status: 'assigned',
        assignedByParent: true,
        submittedAt: DateTime.now(),
      );
      await _taskService.submitTask(task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emoji Sent to ${widget.childName}!'),
          backgroundColor: kAccentGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning task: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmPreset(ProductiveTaskPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(preset.title)),
          ],
        ),
        content: Text(
          'Assign to ${widget.childName}, worth ${_fmt(kTierMinutes[preset.tier]!)} once completed.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _assign(
      title: preset.title,
      emoji: preset.emoji,
      tier: preset.tier,
      category: preset.category,
      minutes: kTierMinutes[preset.tier]!,
    );
  }

  Future<void> _openCustomDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CustomAssignDialog(childName: widget.childName),
    );
    if (result == null) return;
    final tier = result['tier']!;
    await _assign(
      title: result['title']!,
      emoji: '🌱',
      tier: tier,
      category: 'Custom',
      minutes: kTierMinutes[tier]!,
      isCustom: true,
      note: result['note']!.isEmpty ? null : result['note'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text('Assign a Task to ${widget.childName}', style: const TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _openCustomDialog,
                icon: const Icon(Icons.add),
                label: const Text('Write a custom task'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TierChip(
                      label: 'All',
                      active: _tierFilter == 'ALL',
                      onTap: () => setState(() => _tierFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    ..._tiers.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TierChip(
                            label: '${kTierMinutes[t]} min',
                            active: _tierFilter == t,
                            onTap: () => setState(() => _tierFilter = t),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _filteredPresets
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PresetCard(preset: p, onTap: () => _confirmPreset(p)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomAssignDialog extends StatefulWidget {
  final String childName;

  const _CustomAssignDialog({required this.childName});

  @override
  State<_CustomAssignDialog> createState() => _CustomAssignDialogState();
}

class _CustomAssignDialogState extends State<_CustomAssignDialog> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String _tier = 'S';

  static const List<String> _tiers = ['XS', 'S', 'M', 'L', 'XL'];

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _titleController.text.trim().length >= 2;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Task for ${widget.childName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'What do you want them to do?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLength: 240,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a quick note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Worth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _tiers
                  .map((t) => ChoiceChip(
                        label: Text('${kTierMinutes[t]} min'),
                        selected: _tier == t,
                        onSelected: (_) => setState(() => _tier = t),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit
              ? () => Navigator.pop(context, {
                    'title': _titleController.text.trim(),
                    'note': _noteController.text.trim(),
                    'tier': _tier,
                  })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
