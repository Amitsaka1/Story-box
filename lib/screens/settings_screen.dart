import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local-only preferences (no backend endpoint for these yet).
  // Wire these to shared_preferences yourself if you want them to persist.
  String _theme = 'System';
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- Account (backend-connected) ----------------
          _SectionTitle('Account'),
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text((user?.username ?? '?').substring(0, 1).toUpperCase())),
              title: Text(user?.username ?? 'Loading...'),
              subtitle: user != null ? Text('Member since ${user.createdAt.toLocal().toString().split(' ').first}') : null,
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Appearance (LOCAL ONLY) ----------------
          _SectionTitle('Appearance'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  trailing: DropdownButton<String>(
                    value: _theme,
                    underline: const SizedBox(),
                    items: ['Light', 'Dark', 'System']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _theme = v ?? _theme),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Notifications (LOCAL ONLY) ----------------
          _SectionTitle('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Push notifications'),
                  value: _pushEnabled,
                  onChanged: (v) => setState(() => _pushEnabled = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sound'),
                  value: _soundEnabled,
                  onChanged: (v) => setState(() => _soundEnabled = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibration'),
                  value: _vibrationEnabled,
                  onChanged: (v) => setState(() => _vibrationEnabled = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Security (backend-connected) ----------------
          _SectionTitle('Security'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordSheet(context),
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Activity / Support (LOCAL / placeholder) ----------------
          _SectionTitle('Activity'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: wire to a real endpoint once you build one
              },
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle('Support'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & contact support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.star_border),
                  title: const Text('Rate the app / feedback'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Session (backend-connected) ----------------
          _SectionTitle('Session'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              subtitle: const Text('Signing in on another device logs you out here automatically.'),
              onTap: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Danger zone ----------------
          _SectionTitle('Danger zone'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete account', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Not available yet -- backend endpoint not built.'),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to log in again to access your account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<AuthProvider>().logout();
              // Your root widget should watch AuthProvider.isLoggedIn and
              // swap to the login screen automatically when it goes false.
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_currentController.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (_newController.text == _currentController.text) {
      setState(() => _error = 'New password must be different from the current one.');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }

    setState(() => _submitting = true);
    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    setState(() {
      _submitting = false;
      if (ok) {
        _done = true;
      } else {
        _error = context.read<AuthProvider>().lastError ?? 'Could not change password.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _done
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                const Text('Password changed successfully.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change password', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _currentController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update password'),
                ),
              ],
            ),
    );
  }
}

