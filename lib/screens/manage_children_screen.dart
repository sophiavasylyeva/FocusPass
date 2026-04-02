import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'parent_dashboard.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  final List<Map<String, String>> _children = [];
  final _childNameController = TextEditingController();
  final _childUsernameController = TextEditingController();
  final _childPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChildren();
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

  Future<void> _loadChildren() async {
    try {
      final parentUid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .get();

      final loadedChildren = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name']?.toString() ?? '',
          'username': data['username']?.toString() ?? '',
          'password': data['password']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _children.clear();
        _children.addAll(loadedChildren);
      });
    } catch (e) {
      print('❌ Failed to load children: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load children')),
      );
    }
  }


  void _showAddChildDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _childNameController,
              decoration: const InputDecoration(
                labelText: "Child's Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _childUsernameController,
              decoration: const InputDecoration(
                labelText: "Child Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _childPasswordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _childNameController.text.trim();
              final username = _childUsernameController.text.trim();
              final password = _childPasswordController.text.trim();

              if (name.isEmpty || username.length < 3 || password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Username must be at least 3 characters and password at least 6 characters'),
                  ),
                );
                return;
              }

              try {
                final parentUid = FirebaseAuth.instance.currentUser!.uid;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(parentUid)
                    .collection('children')
                    .doc(username)
                    .set({
                  'name': name,
                  'username': username,
                  'password': password,
                  'createdAt': FieldValue.serverTimestamp(),
                  'onboardingComplete': false,
                });

                // Add to UI
                setState(() {
                  _children.add({
                    'name': name,
                    'username': username,
                    'password': password,
                  });
                });

                _childNameController.clear();
                _childUsernameController.clear();
                _childPasswordController.clear();
                Navigator.pop(context);
              } catch (e) {
                print('❌ Failed to save child: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error saving child profile')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Add Child', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditChildDialog(int index) {
    final child = _children[index];
    final editNameController = TextEditingController(text: child['name']);
    final editPasswordController = TextEditingController(text: child['password']);
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(
                labelText: "Child's Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: "Child Username",
                border: const OutlineInputBorder(),
                hintText: child['username'],
                filled: true,
                fillColor: Colors.grey[200],
              ),
              controller: TextEditingController(text: child['username']),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: editPasswordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = editNameController.text.trim();
              final newPassword = editPasswordController.text.trim();

              if (newName.isEmpty || newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name cannot be empty and password must be at least 6 characters'),
                  ),
                );
                return;
              }

              try {
                final parentUid = FirebaseAuth.instance.currentUser!.uid;
                final username = child['username']!;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(parentUid)
                    .collection('children')
                    .doc(username)
                    .update({
                  'name': newName,
                  'password': newPassword,
                });

                setState(() {
                  _children[index] = {
                    'name': newName,
                    'username': username,
                    'password': newPassword,
                  };
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Child profile updated')),
                );
              } catch (e) {
                print('Failed to update child: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error updating child profile')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _deleteChild(int index) async {
    final parentUid = FirebaseAuth.instance.currentUser!.uid;
    final username = _children[index]['username'];

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(username)
          .delete();

      setState(() {
        _children.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Child deleted')),
      );
    } catch (e) {
      print('❌ Error deleting child: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting child')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text(
          'Manage Children',
          style: TextStyle(color: Colors.white),
        ),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_children.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No children accounts yet. Add your first child to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            Expanded(
              child: _children.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                itemCount: _children.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final child = _children[index];
                  return Card(
                    child: ListTile(
                      title: Text(child['name'] ?? ''),
                      subtitle: Text('Username: ${child['username']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: kAccentBlue),
                            onPressed: () => _showEditChildDialog(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteChild(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showAddChildDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.white),
                backgroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Child'),
            ),
          ],
        ),
      ),
    );
  }
}
