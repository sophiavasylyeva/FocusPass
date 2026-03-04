import 'package:flutter/material.dart';
import '../utils/constants.dart';
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
  final Map<String, List<String>> _childSelectedApps = {};
  bool applySameForAll = false;
  double unifiedLimit = 1.0;
  bool isLoading = true;

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

    Map<String, List<String>> tempSelectedApps = {};
    for (var doc in childrenSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String;
      final apps = data['selectedApps'];
      if (apps != null && apps is List) {
        tempSelectedApps[name] = List<String>.from(apps);
      } else {
        tempSelectedApps[name] = [];
      }
    }

    Map<String, Map<String, dynamic>> tempRules = {
      for (var name in loadedChildren) name: {'limit': 1.0},
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
      _childSelectedApps.clear();
      _childSelectedApps.addAll(tempSelectedApps);
      isLoading = false;
    });
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
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Apply same rules to all children', style: TextStyle(color: Colors.white)),
              value: applySameForAll,
              activeColor: kAccentBlue,
              inactiveThumbColor: Colors.black,
              inactiveTrackColor: Colors.white54,
              onChanged: (value) => setState(() => applySameForAll = value),
            ),
            const SizedBox(height: 12),
            if (applySameForAll)
              _buildUnifiedRules()
            else
              Expanded(child: _buildIndividualRules(children)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saveRulesToFirestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedRules() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Children must complete 5 questions to earn 15 minutes of screen time',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSlider('Daily Time Limit for All Apps (hours)', unifiedLimit, (val) => setState(() => unifiedLimit = val),
              customValues: [0.5, 1, 1.5, 2, 2.5, 3]),
        ],
      ),
    );
  }

  Widget _buildIndividualRules(List<String> children) {
    return ListView.builder(
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child, style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '5 questions = 15 minutes screen time',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSlider('Daily Time Limit for All Apps (hours)', _rules[child]!['limit'],
                        (val) => setState(() => _rules[child]!['limit'] = val),
                    customValues: [0.5, 1, 1.5, 2, 2.5, 3]),
                _buildSelectedApps(child),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedApps(String childName) {
    final apps = _childSelectedApps[childName] ?? [];
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No apps selected for this child',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Applies to:',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: apps.map((app) => Chip(
              label: Text(app, style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.green.shade50,
              side: BorderSide(color: Colors.green.shade200),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label,
      double value,
      ValueChanged<double> onChanged, {
        bool isRatio = false,
        List<double>? customValues,
      }) {
    List<double> markers = customValues ?? [1, 2, 3, 4, 5];
    int currentIndex = markers.indexWhere((e) => (e - value).abs() < 0.1);
    currentIndex = currentIndex == -1 ? 0 : currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black)),
        Slider(
          value: currentIndex.toDouble(),
          min: 0,
          max: (markers.length - 1).toDouble(),
          divisions: markers.length - 1,
          label: isRatio ? '${markers[currentIndex]}x' : '${markers[currentIndex]} hrs',
          onChanged: (val) => onChanged(markers[val.toInt()]),
        ),
      ],
    );
  }

  Future<void> _saveRulesToFirestore() async {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Screen time rules saved')),
      );
    } catch (e) {
      print('❌ Failed to save screen time rules: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save screen time rules')),
      );
    }
  }
}
