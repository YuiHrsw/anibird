import 'package:flutter/material.dart';

import '../../../app/app_layout_scope.dart';
import '../../../backend/models/bangumi_profile.dart';

class SettingsEntryTile extends StatelessWidget {
  const SettingsEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final useRailNavigation =
        AppLayoutScope.maybeOf(context)?.useRailNavigation ?? false;
    if (useRailNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}

class SettingsSectionDefinition {
  const SettingsSectionDefinition({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
}

class BangumiProfileCard extends StatelessWidget {
  const BangumiProfileCard({
    super.key,
    required this.profile,
    required this.error,
    required this.authError,
    required this.isLoading,
    required this.isAuthorizing,
    required this.onRefresh,
    required this.onLogin,
    required this.onLogout,
  });

  final BangumiProfile? profile;
  final String? error;
  final String? authError;
  final bool isLoading;
  final bool isAuthorizing;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLogin;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bangumi 登录态',
                    style: textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onRefresh == null
                      ? null
                      : () async {
                          await onRefresh!.call();
                        },
                  child: Text(isLoading ? '刷新中...' : '刷新'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: onLogin == null
                      ? null
                      : () async {
                          await onLogin!.call();
                        },
                  child: Text(isAuthorizing ? '授权中...' : 'OAuth 登录'),
                ),
                OutlinedButton(
                  onPressed: onLogout == null
                      ? null
                      : () async {
                          await onLogout!.call();
                        },
                  child: const Text('退出 Bangumi'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (authError != null) ...[
              Text(
                authError!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Text(
                error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              )
            else if (profile == null)
              Text(
                '填写 OAuth 配置后可通过浏览器授权，并在这里读取当前用户信息。',
                style: textTheme.bodyMedium,
              )
            else ...[
              Text(profile!.displayName, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('@${profile!.username}', style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              if (profile!.sign.isNotEmpty) ...[
                Text(profile!.sign, style: textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MetaChip(label: 'ID ${profile!.id}'),
                  MetaChip(label: '用户组 ${profile!.group}'),
                  if (profile!.location.isNotEmpty)
                    MetaChip(label: profile!.location),
                  if (profile!.site.isNotEmpty) MetaChip(label: profile!.site),
                  if (profile!.permissions.subjectWikiEdit)
                    const MetaChip(label: '可编辑条目 Wiki'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
