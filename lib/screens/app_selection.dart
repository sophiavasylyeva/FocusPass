import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/family_activity_picker_service.dart';
import 'child_age.dart';

class AppSelectionScreen extends StatefulWidget {
  final String childName;

  const AppSelectionScreen({
    super.key,
    required this.childName,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  // ─── Android / legacy curated checklist ──────────────────────────────────

  final Map<String, bool> _selectedApps = {
    'Instagram': false,
    'TikTok': false,
    'YouTube': false,
    'YouTube Shorts': false,
    'Snapchat': false,
    'X (Twitter)': false,
  };

  final Map<String, IconData> _appIcons = {
    'Instagram': Icons.camera_alt,
    'TikTok': Icons.music_note,
    'YouTube': Icons.play_circle_fill,
    'YouTube Shorts': Icons.video_library,
    'Snapchat': Icons.chat_bubble,
    'X (Twitter)': Icons.tag,
  };

  final Map<String, Color> _appColors = {
    'Instagram': Color(0xFFE1306C),
    'TikTok': Color(0xFF010101),
    'YouTube': Color(0xFFFF0000),
    'YouTube Shorts': Color(0xFFFF0000),
    'Snapchat': Color(0xFFFFFC00),
    'X (Twitter)': Color(0xFF000000),
  };

  bool get _hasSelectedApps => _selectedApps.values.any((selected) => selected);

  // ─── iOS real FamilyActivityPicker ────────────────────────────────────────

  FamilyActivityPickerResult? _iosSelection;
  bool _isPicking = false;

  Future<void> _openIOSPicker() async {
    setState(() => _isPicking = true);
    try {
      final result = await FamilyActivityPickerService.show();
      if (result != null) {
        setState(() => _iosSelection = result);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.code == 'NOT_AUTHORIZED'
          ? 'Screen Time access was not granted. Please allow it in the prompt, or in Settings > Screen Time, then try again.'
          : 'Could not open the app picker: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the app picker: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _saveIOSSelectionAndContinue() async {
    final selection = _iosSelection;
    if (selection == null || selection.isEmpty) return;

    final query = await FirebaseFirestore.instance
        .collectionGroup('children')
        .where('name', isEqualTo: widget.childName)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'usesFamilyActivityPicker': true,
        'familyActivityAppCount': selection.appCount,
        'familyActivityCategoryCount': selection.categoryCount,
      });
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChildAgeScreen(childName: widget.childName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Select Apps', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Platform.isIOS ? _buildIOSPickerBody() : _buildAndroidChecklistBody(),
      ),
    );
  }

  Widget _buildIOSPickerBody() {
    final selection = _iosSelection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose which apps and categories ${widget.childName}'s screen time limit will apply to.",
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          "This opens Apple's own Screen Time picker, listing every app on this device.",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (selection != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: kAccentGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${selection.appCount} ${selection.appCount == 1 ? 'app' : 'apps'} and '
                    '${selection.categoryCount} ${selection.categoryCount == 1 ? 'category' : 'categories'} selected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: _isPicking ? null : _openIOSPicker,
          icon: const Icon(Icons.apps),
          label: Text(selection == null ? 'Choose Apps' : 'Change Selection'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54, width: 1.5),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: (selection != null && !selection.isEmpty) ? _saveIOSSelectionAndContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: (selection != null && !selection.isEmpty) ? kAccentBlue : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAndroidChecklistBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What apps would you like ${widget.childName}'s screen time limit to apply to?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: _selectedApps.keys.map((appName) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  title: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appColors[appName],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _appIcons[appName],
                          color: appName == 'Snapchat' ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(appName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  value: _selectedApps[appName],
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedApps[appName] = value ?? false;
                    });
                  },
                  activeColor: kAccentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.bottomRight,
          child: Stack(
            children: [
              ElevatedButton(
                onPressed: _hasSelectedApps ? () async {
                  await FirebaseFirestore.instance
                      .collectionGroup('children')
                      .where('name', isEqualTo: widget.childName)
                      .get()
                      .then((query) {
                    if (query.docs.isNotEmpty) {
                      query.docs.first.reference.update({
                        'selectedApps': _selectedApps.entries
                            .where((entry) => entry.value)
                            .map((entry) => entry.key)
                            .toList(),
                      });
                    }
                  });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ChildAgeScreen(childName: widget.childName)),
          );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasSelectedApps ? kAccentBlue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (!_hasSelectedApps)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
