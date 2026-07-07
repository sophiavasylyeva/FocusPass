import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/hour_cap_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent_dashboard.dart';

class ScreenTimeRulesScreen extends StatefulWidget {
  const ScreenTimeRulesScreen({super.key});

  @override
  State<ScreenTimeRulesScreen> createState() => _ScreenTimeRulesScreenState();
}

class _ScreenTimeRulesScreenState extends State<ScreenTimeRulesScreen> {
  final Map<String, Map<String, dynamic>> _rules = {};
  bool applySameForAll = false;
  double unifiedLimit = 2.0;
  bool isLoading = true;
  bool _isSaving = false;

  static const List<double> _hourOptions = [1, 1.5, 2, 2.5, 3, 4];

  @override
  void initState() {
    super.initState();
    _initializeScreenTimeRules();
  }

  Future<void> _navigateToParentDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final parentName = doc.data()?['name'] ?? 'Parent';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ParentDashboardScreen(parentName: parentName)),
        (route) => false,
      );
    }
  }

  Future<void> _initializeScreenTimeRules() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final settingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('screenTimeRules');

    final childrenRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children');

    final settingsDoc = await settingsRef.get();
    final childrenSnapshot = await childrenRef.get();

    final loadedChildren = childrenSnapshot.docs.map((doc) => doc.data()['name'] as String).toList();

    Map<String, Map<String, dynamic>> tempRules = {
      for (var name in loadedChildren) name: {'limit': 2.0},
    };

    if (settingsDoc.exists) {
      final data = settingsDoc.data()!;
      applySameForAll = data['applySameForAll'] ?? false;

      if (applySameForAll) {
        unifiedLimit = (data['unifiedRules']?['limit'] ?? 2.0).toDouble();
      } else {
        final childrenData = data['children'] as Map<String, dynamic>? ?? {};
        for (var name in tempRules.keys) {
          if (childrenData.containsKey(name)) {
            tempRules[name] = {
              'limit': (childrenData[name]['limit'] ?? 2.0).toDouble(),
            };
          }
        }
      }
    }

    setState(() {
      _rules.clear();
      _rules.addAll(tempRules);
      isLoading = false;
    });
  }

  double _closestOption(double value) {
    if (_hourOptions.contains(value)) return value;
    return _hourOptions.reduce((a, b) => (a - value).abs() < (b - value).abs() ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final children = _rules.keys.toList();

    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Set Screen Time Rules', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to Dashboard',
            onPressed: () => _navigateToParentDashboard(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Set a daily screen time cap',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your kids can only earn screen time by completing real activities — never more than the daily cap. You can change this anytime.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    title: const Text('Apply the same cap to all children', style: TextStyle(fontSize: 14)),
                    value: applySameForAll,
                    activeColor: kDarkGreen,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() => applySameForAll = value),
                  ),
                ),
                const SizedBox(height: 16),
                if (applySameForAll)
                  HourCapCard(
                    hours: _closestOption(unifiedLimit),
                    options: _hourOptions,
                    onChanged: (h) => setState(() => unifiedLimit = h),
                  )
                else
                  ...children.map((child) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: HourCapCard(
                          label: "${child.toUpperCase()}'S DAILY LIMIT",
                          hours: _closestOption(_rules[child]!['limit']),
                          options: _hourOptions,
                          onChanged: (h) => setState(() => _rules[child]!['limit'] = h),
                        ),
                      )),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveRulesToFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save and start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No screen time without earning it. No exceptions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Future<void> _saveRulesToFirestore() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;

      final Map<String, dynamic> dataToSave = {
        'applySameForAll': applySameForAll,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (applySameForAll) {
        dataToSave['unifiedRules'] = {
          'limit': unifiedLimit,
        };
      } else {
        final Map<String, dynamic> childrenData = {};
        _rules.forEach((childName, settings) {
          childrenData[childName] = {
            'limit': settings['limit'],
          };
        });
        dataToSave['children'] = childrenData;
      }

      await firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('screenTimeRules')
          .set(dataToSave);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Screen time rules saved')),
      );
    } catch (e) {
      print('❌ Failed to save screen time rules: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save screen time rules')),
      );
    }
  }
}
