import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../shared/widgets/app_cards.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.themeMode,
    required this.onThemeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool? _notificationsEnabled;
  String? _vapidKey;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final user = deps.auth.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text('Profilo', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayLabel ?? 'Utente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(user?.email ?? ''),
              const SizedBox(height: 4),
              Chip(label: Text(user?.role ?? 'USER')),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: deps.auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tema', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                  ),
                  ButtonSegment(value: ThemeMode.light, label: Text('Chiaro')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
                ],
                selected: {widget.themeMode},
                onSelectionChanged: (value) =>
                    widget.onThemeChanged(value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifiche', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _notificationsEnabled == true
                    ? 'Notifiche native locali abilitate.'
                    : 'Permesso notifiche non ancora concesso.',
              ),
              if (_vapidKey != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Backend Web Push disponibile. L\'app nativa usa notifiche locali per il workout.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Abilita'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _sendLocalTest,
                    icon: const Icon(Icons.notification_add),
                    label: const Text('Test locale'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadNotificationState() async {
    final deps = AppScope.of(context);
    final enabled = await deps.notifications.areNotificationsEnabled();
    String? vapid;
    try {
      vapid = await deps.pushApi.getVapidPublicKey();
    } catch (_) {
      vapid = null;
    }
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _vapidKey = vapid;
    });
  }

  Future<void> _requestPermission() async {
    final enabled = await AppScope.of(
      context,
    ).notifications.requestPermission();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _message = enabled
          ? 'Permesso notifiche concesso.'
          : 'Permesso non concesso.';
    });
  }

  Future<void> _sendLocalTest() async {
    await AppScope.of(context).notifications.show(
      id: 7,
      title: 'LifePlanner',
      body: 'Notifica locale di test.',
    );
  }
}
