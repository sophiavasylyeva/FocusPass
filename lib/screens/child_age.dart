import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'subject_interest.dart';

class ChildAgeScreen extends StatefulWidget {
  final String childName;

  const ChildAgeScreen({super.key, required this.childName});

  @override
  State<ChildAgeScreen> createState() => _ChildAgeScreenState();
}

class _ChildAgeScreenState extends State<ChildAgeScreen> {
  String? _selectedAgeRange;

  final List<String> _ageRanges = [
    '5-7 yrs old',
    '8-10 yrs old',
    '11-13 yrs old',
    '14-16 yrs old',
    '17-18 yrs old',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Child Age', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How old is ${widget.childName}?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
            ),
            const SizedBox(height: 20),
            ..._ageRanges.map((ageRange) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: RadioListTile<String>(
                title: Text(ageRange, style: const TextStyle(color: Colors.black)),
                value: ageRange,
                groupValue: _selectedAgeRange,
                activeColor: kAccentBlue,
                onChanged: (value) => setState(() => _selectedAgeRange = value),
              ),
            )),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomRight,
              child: Stack(
                children: [
                  ElevatedButton(
                    onPressed: _selectedAgeRange != null
                        ? () async {
                      final query = await FirebaseFirestore.instance
                          .collectionGroup('children')
                          .where('name', isEqualTo: widget.childName)
                          .get();

                      if (query.docs.isNotEmpty) {
                        await query.docs.first.reference.update({
                          'ageRange': _selectedAgeRange,
                        });
                      }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SubjectInterestScreen(childName: widget.childName),
                ),
              );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedAgeRange != null ? kAccentBlue : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                  if (_selectedAgeRange == null)
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
            )
          ],
        ),
      ),
    );
  }
}
