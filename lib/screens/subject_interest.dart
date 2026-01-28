import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'child_dashboard_screen.dart';

class SubjectInterestScreen extends StatefulWidget {
  final String childName;

  const SubjectInterestScreen({super.key, required this.childName});

  @override
  State<SubjectInterestScreen> createState() => _SubjectInterestScreenState();
}

class _SubjectInterestScreenState extends State<SubjectInterestScreen> {
  final List<String> _subjects = [
    'Math', 'Science', 'English', 'History', 'Art', 'Coding', 'Geography', 'Reading',
  ];

  List<String> _selectedSubjects = [];
  bool _isLoading = false;

  bool get _hasSelectedSubjects => _selectedSubjects.isNotEmpty;

  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
      } else {
        _selectedSubjects.add(subject);
      }
    });
  }

  Future<void> _submitSubjects() async {
    if (!_hasSelectedSubjects) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: widget.childName)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'subjectsOfInterest': _selectedSubjects,
          'onboardingComplete': true,
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChildDashboardScreen(childName: widget.childName),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Child not found in Firestore.')),
        );
      }
    } catch (e) {
      print('❌ Error saving subjects: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Pick Your Subjects', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select subjects you like:',
                style: TextStyle(fontSize: 20, color: Colors.white)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _subjects.map((subject) {
                  final isSelected = _selectedSubjects.contains(subject);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      onTap: () => _toggleSubject(subject),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? kAccentBlue : Colors.white54,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 18,
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasSelectedSubjects ? _submitSubjects : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasSelectedSubjects ? kAccentBlue : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Finish & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (!_hasSelectedSubjects)
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
          ],
        ),
      ),
    );
  }
}
