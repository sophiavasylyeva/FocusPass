import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/child_auth_service.dart';
import 'parent_dashboard.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key, ChildAuthService? childAuthService})
    : _childAuthService = childAuthService;

  /// Injectable only for tests — production callers always get the real
  /// backend-calling implementation (see `_ManageChildrenScreenState`).
  final ChildAuthService? _childAuthService;

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  final List<Map<String, dynamic>> _children = [];
  final _childNameController = TextEditingController();
  final _childUsernameController = TextEditingController();
  final _childFamilyCodeController = TextEditingController();
  final _childPasswordController = TextEditingController();
  final _addChildFormKey = GlobalKey<FormState>();

  final Set<String> _deletingChildIds = {};

  late final ChildAuthService _childAuthService =
      widget._childAuthService ?? ChildAuthService();

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _navigateToParentDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final parentName = doc.data()?['name'] ?? 'Parent';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ParentDashboardScreen(parentName: parentName),
        ),
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
        final data = doc.data();
        return <String, dynamic>{
          'docId': doc.id,
          'name': data['name']?.toString() ?? '',
          'username': data['username']?.toString() ?? '',
          
          'password': data['password']?.toString() ?? '',
          'familyCode': data['familyCode']?.toString(),
          'authUid': data['authUid']?.toString(),
          'authMigrated': data['authMigrated'] == true,
          'authEnabled': data['authEnabled'] == true,
        };
      }).toList();

      setState(() {
        _children.clear();
        _children.addAll(loadedChildren);
      });
    } catch (e) {
      print('❌ Failed to load children: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load children')));
    }
  }

  void _showAddChildDialog() {
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (isSubmitting) return; // guard against double submission
            if (!_addChildFormKey.currentState!.validate()) return;

            final name = _childNameController.text.trim();
            final username = _childUsernameController.text.trim();
            final familyCode = _childFamilyCodeController.text.trim();
            final password = _childPasswordController.text;

            setDialogState(() => isSubmitting = true);

            try {
             
              ChildAuthService.requireAuthenticatedParent(
                FirebaseAuth.instance.currentUser?.uid,
              );

              
              final childId = username;

              await _childAuthService.createChildAccount(
                childId: childId,
                name: name,
                username: username,
                familyCode: familyCode,
                password: password,
              );

              await _loadChildren();

              if (!dialogContext.mounted) return;
              _childNameController.clear();
              _childUsernameController.clear();
              _childFamilyCodeController.clear();
              _childPasswordController.clear();
              Navigator.pop(dialogContext);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Child account created')),
              );
            } on ChildAuthException catch (e) {
              setDialogState(() => isSubmitting = false);
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            } catch (e) {
              setDialogState(() => isSubmitting = false);
              print('❌ Failed to save child: $e');
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Error saving child profile')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Add a child'),
            content: Form(
              key: _addChildFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _childNameController,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: "Child's Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: ChildAuthValidation.validateName,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _childUsernameController,
                    enabled: !isSubmitting,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: "Child Username",
                      border: OutlineInputBorder(),
                    ),
                    validator: ChildAuthValidation.validateUsername,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _childFamilyCodeController,
                    enabled: !isSubmitting,
                    maxLength: 12,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Family Code',
                      border: OutlineInputBorder(),
                    ),
                    validator: ChildAuthValidation.validateFamilyCode,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _childPasswordController,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: ChildAuthValidation.validatePassword,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your child will sign in using their family code, username, '
                    'and password.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Child',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditChildDialog(int index) {
    final child = _children[index];
    final isMigrated = isChildAuthMigrated(child);
    final editNameController = TextEditingController(
      text: child['name'] as String?,
    );
    
    final editPasswordController = TextEditingController(
      text: child['password'] as String?,
    );
    bool obscurePassword = true;

  
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isResettingPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> handleResetPassword() async {
            if (isResettingPassword) return; // guard against double submission
            final newPassword = newPasswordController.text;
            final confirmPassword = confirmPasswordController.text;

            final validationError = ChildAuthValidation.validatePassword(
              newPassword,
            );
            if (validationError != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(validationError)));
              return;
            }
            if (newPassword != confirmPassword) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passwords do not match')),
              );
              return;
            }

            setDialogState(() => isResettingPassword = true);
            try {
              await _childAuthService.resetChildPassword(
                childId: child['docId'] as String,
                newPassword: newPassword,
              );

              newPasswordController.clear();
              confirmPasswordController.clear();

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Password reset successfully')),
              );
            } on ChildAuthException catch (e) {
              setDialogState(() => isResettingPassword = false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            } catch (e) {
              setDialogState(() => isResettingPassword = false);
              print('❌ Failed to reset child password: $e');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error resetting password')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Edit Child'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editNameController,
                    enabled: !isResettingPassword,
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
                      hintText: child['username'] as String?,
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    controller: TextEditingController(
                      text: child['username'] as String?,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isMigrated) ...[
                  
                    const Divider(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Reset Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      enabled: !isResettingPassword,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureNewPassword = !obscureNewPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordController,
                      enabled: !isResettingPassword,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirmPassword =
                                !obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isResettingPassword
                            ? null
                            : handleResetPassword,
                        child: isResettingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Reset Password'),
                      ),
                    ),
                  ] else
                  
                    TextField(
                      controller: editPasswordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isResettingPassword
                    ? null
                    : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: isResettingPassword
                    ? null
                    : () async {
                        final newName = editNameController.text.trim();

                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Name cannot be empty'),
                            ),
                          );
                          return;
                        }

                        if (!isMigrated) {
                          final newPassword = editPasswordController.text
                              .trim();
                          if (newPassword.length <
                              ChildAuthValidation.minPasswordLength) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password must be at least 6 characters',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        try {
                          final parentUid =
                              FirebaseAuth.instance.currentUser!.uid;
                          final docId = child['docId'] as String;
                          final username = child['username'] as String;

                          final updates = <String, dynamic>{'name': newName};
                          // TEMPORARY legacy behavior: only a non-migrated
                          // child's plaintext password is ever written
                          // here. An authenticated child's password is
                          // never touched by this dialog's Save action.
                          if (!isMigrated) {
                            updates['password'] = editPasswordController.text
                                .trim();
                          }

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(parentUid)
                              .collection('children')
                              .doc(docId)
                              .update(updates);

                          setState(() {
                            _children[index] = {
                              ..._children[index],
                              'name': newName,
                              'username': username,
                              if (!isMigrated)
                                'password': editPasswordController.text.trim(),
                            };
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Child profile updated'),
                            ),
                          );
                        } catch (e) {
                          print('Failed to update child: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error updating child profile'),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteChild(int index) async {
    final child = _children[index];

    if (isChildAuthMigrated(child)) {
      await _deleteAuthenticatedChild(child);
      return;
    }

   
    final parentUid = FirebaseAuth.instance.currentUser!.uid;
    final docId = child['docId'] as String;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(docId)
          .delete();

      setState(() {
        _children.removeAt(index);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Child deleted')));
    } catch (e) {
      print('❌ Error deleting child: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error deleting child')));
    }
  }

  Future<void> _deleteAuthenticatedChild(Map<String, dynamic> child) async {
    final docId = child['docId'] as String;
    if (_deletingChildIds.contains(docId))
      return; // guard against double submission

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this child account?'),
        content: Text(
          'This will permanently disable ${child['name']}\'s sign-in. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_deletingChildIds.contains(docId)) return;

    setState(() => _deletingChildIds.add(docId));
    try {
      await _childAuthService.deleteChildAccount(childId: docId);
      await _loadChildren();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Child account deleted')));
    } on ChildAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      print('❌ Failed to delete child account: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting child account')),
      );
    } finally {
      if (mounted) setState(() => _deletingChildIds.remove(docId));
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        final isDeleting = _deletingChildIds.contains(
                          child['docId'],
                        );
                        return Card(
                          child: ListTile(
                            title: Text(child['name'] as String? ?? ''),
                            subtitle: Text(
                              'Username: ${child['username'] ?? ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: kAccentBlue,
                                  ),
                                  onPressed: isDeleting
                                      ? null
                                      : () => _showEditChildDialog(index),
                                ),
                                isDeleting
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
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
