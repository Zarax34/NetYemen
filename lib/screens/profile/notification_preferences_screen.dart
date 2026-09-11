// lib/screens/profile/notification_preferences_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';

/// شاشة إعدادات الإشعارات — تحميل الإعدادات الحالية وتبديلها.
///
/// RPCs: `get_notification_preferences`, `update_notification_preferences`.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  // القيم الافتراضية = true حتى يحمّل الإعدادات
  bool _networkAdded = true;
  bool _packageAdded = true;
  bool _stockRestored = true;
  bool _platformUpdates = true;
  bool _offersAnnouncements = true;
  bool _loaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await ref.read(supabaseServiceProvider).getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _networkAdded = prefs['network_added_enabled'] ?? true;
        _packageAdded = prefs['package_added_enabled'] ?? true;
        _stockRestored = prefs['stock_restored_enabled'] ?? true;
        _platformUpdates = prefs['platform_updates_enabled'] ?? true;
        _offersAnnouncements = prefs['offers_announcements_enabled'] ?? true;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(supabaseServiceProvider).updateNotificationPreferences(
            networkAddedEnabled: _networkAdded,
            packageAddedEnabled: _packageAdded,
            stockRestoredEnabled: _stockRestored,
            platformUpdatesEnabled: _platformUpdates,
            offersAnnouncementsEnabled: _offersAnnouncements,
          );
      ref.invalidate(notificationPreferencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات الإشعارات'),
          backgroundColor: AppTheme.accentDark,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الحفظ: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الإشعارات'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSwitch(
                  title: 'شبكة جديدة',
                  subtitle: 'عند إضافة شبكة جديدة قريبة منك',
                  value: _networkAdded,
                  onChanged: (v) => setState(() => _networkAdded = v),
                ),
                _buildSwitch(
                  title: 'باقة جديدة',
                  subtitle: 'عند إضافة باقة جديدة في شبكة تتابعها',
                  value: _packageAdded,
                  onChanged: (v) => setState(() => _packageAdded = v),
                ),
                _buildSwitch(
                  title: 'توفّر المخزون',
                  subtitle: 'عند عودة المخزون لباقة نفدت',
                  value: _stockRestored,
                  onChanged: (v) => setState(() => _stockRestored = v),
                ),
                _buildSwitch(
                  title: 'تحديثات المنصة',
                  subtitle: 'إشعارات عامة من NetYemen',
                  value: _platformUpdates,
                  onChanged: (v) => setState(() => _platformUpdates = v),
                ),
                _buildSwitch(
                  title: 'العروض والإعلانات',
                  subtitle: 'عروض خاصة وحملات ترويجية',
                  value: _offersAnnouncements,
                  onChanged: (v) => setState(() => _offersAnnouncements = v),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('حفظ'),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primary,
      ),
    );
  }
}
