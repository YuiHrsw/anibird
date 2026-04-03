import 'package:flutter/material.dart';

import '../../../app/app_layout_scope.dart';
import '../../../app/app_scope.dart';
import '../../state/settings_store.dart';
import 'bangumi_settings_section.dart';
import 'model_settings_section.dart';
import 'settings_widgets.dart';
import 'storage_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsSection _selectedSection = _SettingsSection.model;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final store = context.readAppDependencies.settingsStore;
      if (!store.value.isLoaded) {
        store.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.settingsStore;
    return ValueListenableBuilder<SettingsState>(
      valueListenable: store,
      builder: (context, state, _) {
        final isWide =
            AppLayoutScope.maybeOf(context)?.useRailNavigation ?? false;
        if (!isWide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildNarrowSettings(context, state),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: _buildWideSettings(context, state),
        );
      },
    );
  }

  Widget _buildNarrowSettings(BuildContext context, SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设置', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '按类别管理模型、Bangumi 账号和缓存。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ..._buildSectionEntries(context, state, navigate: true),
      ],
    );
  }

  Widget _buildWideSettings(BuildContext context, SettingsState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _buildSectionDefinition(state, _selectedSection);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: ListView(
            children: [
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              Text('设置', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '按类别管理模型、Bangumi 账号和缓存。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ..._buildSectionEntries(context, state, navigate: false),
            ],
          ),
        ),
        VerticalDivider(
          width: 24,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),
        Expanded(
          child: ListView(
            children: [
              Text(
                selected.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ...selected.children,
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSectionEntries(
    BuildContext context,
    SettingsState state, {
    required bool navigate,
  }) {
    return _SettingsSection.values.map((section) {
      final definition = _buildSectionDefinition(state, section);
      return SettingsEntryTile(
        icon: definition.icon,
        title: definition.title,
        subtitle: definition.subtitle,
        selected: !navigate && _selectedSection == section,
        onTap: () {
          if (navigate) {
            setState(() {
              _selectedSection = section;
            });
            _openSectionPage(
              child: SettingsSectionPage(
                title: definition.title,
                children: definition.children,
              ),
            );
            return;
          }
          setState(() {
            _selectedSection = section;
          });
        },
      );
    }).toList(growable: false);
  }

  SettingsSectionDefinition _buildSectionDefinition(
    SettingsState state,
    _SettingsSection section,
  ) {
    switch (section) {
      case _SettingsSection.model:
        return SettingsSectionDefinition(
          icon: Icons.smart_toy_outlined,
          title: '模型配置',
          subtitle: state.config.llmModel.trim().isEmpty
              ? 'Base URL、API Key、Model'
              : state.config.llmModel.trim(),
          children: [
            ModelSettingsSection(store: context.settingsStore),
          ],
        );
      case _SettingsSection.bangumi:
        return SettingsSectionDefinition(
          icon: Icons.api_outlined,
          title: 'Bangumi 设置',
          subtitle: state.config.bangumiPrivateApiBaseUrl.trim().isEmpty
              ? 'API、OAuth、账号状态'
              : (state.bangumiProfile?.displayName ??
                    state.config.bangumiPrivateApiBaseUrl.trim()),
          children: [
            BangumiSettingsSection(store: context.settingsStore),
          ],
        );
      case _SettingsSection.storage:
        return SettingsSectionDefinition(
          icon: Icons.cleaning_services_outlined,
          title: '存储设置',
          subtitle: '缓存清理与本地数据管理',
          children: [
            StorageSettingsSection(
              state: state,
              onClearImageCache: _clearImageCache,
              onClearAllCaches: _clearAllCaches,
            ),
          ],
        );
    }
  }

  Future<void> _clearImageCache() async {
    try {
      await context.readAppDependencies.settingsStore.clearImageCache();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片缓存已清除')));
  }

  Future<void> _clearAllCaches() async {
    try {
      await context.readAppDependencies.settingsStore.clearAllCaches();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('全部缓存已清除')));
  }

  Future<void> _openSectionPage({
    required Widget child,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => child,
      ),
    );
  }
}

enum _SettingsSection {
  model,
  bangumi,
  storage,
}
