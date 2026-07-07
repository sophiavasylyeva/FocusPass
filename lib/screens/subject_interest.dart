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
  final List<Map<String, String>> _categories = [
    {'name': 'Home', 'emoji': '🏠'},
    {'name': 'Learning', 'emoji': '📖'},
    {'name': 'Family', 'emoji': '👨‍👩‍👧'},
    {'name': 'Outdoors', 'emoji': '🌿'},
    {'name': 'Self-care', 'emoji': '🧘'},
  ];

  List<String> _selectedCategories = [];
  bool _isLoading = false;

  bool get _hasSelected => _selectedCategories.isNotEmpty;

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _submit() async {
    if (!_hasSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category.')),
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
          'taskCategories': _selectedCategories,
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
          const SnackBar(content: Text('Child not found. Please try again.')),
        );
      }
    } catch (e) {
      print('❌ Error saving categories: $e');
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
        title: const Text('Pick Your Task Categories', style: TextStyle(color: Colors.white)),
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
                  const Text(
                    'Select the types of productive tasks you\'ll work on:',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategories.contains(cat['name']);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () => _toggleCategory(cat['name']!),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? kAccentBlue : Colors.white54,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              child: Row(
                                children: [
                                  Text(cat['emoji']!, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 14),
                                  Text(
                                    cat['name']!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                          onPressed: _hasSelected ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSelected ? kAccentBlue : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Finish & Continue',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (!_hasSelected)
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
