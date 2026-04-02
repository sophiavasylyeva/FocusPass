import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        child: Column(
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
        ),
      ),
    );
  }
}
