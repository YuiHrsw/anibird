import 'package:flutter/material.dart';

import '../../../app/app_layout_scope.dart';
import '../../../app/app_scope.dart';
import '../../../backend/models/app_config.dart';
import 'bangumi_settings_section.dart';
import 'model_settings_section.dart';
import 'settings_widgets.dart';
import 'storage_settings_section.dart';
import '../../state/settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsStore _store;
  _SettingsSection _selectedSection = _SettingsSection.model;
  bool _hasBoundStore = false;
  bool _hasSyncedInitialConfig = false;
  AppConfig? _draftConfig;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasBoundStore) {
      _store = AppScope.of(context).settingsStore;
      _hasBoundStore = true;
    }
    if (!_store.value.isLoaded) {
      _store.load();
    }
    if (_store.value.isLoaded && !_hasSyncedInitialConfig) {
      _draftConfig = _store.value.config;
      _hasSyncedInitialConfig = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: _store,
      builder: (context, state, _) {
        if (state.isLoaded && !_hasSyncedInitialConfig) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hasSyncedInitialConfig) {
              return;
            }
            setState(() {
              _draftConfig = state.config;
              _hasSyncedInitialConfig = true;
            });
          });
        }
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
    final selected = _buildSectionDefinition(context, state, _selectedSection);
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
              ..._buildSectionEntries(
                context,
                state,
                navigate: false,
              ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (selected.actionLabel != null)
                    TextButton(
                      onPressed: selected.onAction == null
                          ? null
                          : () async {
                              await selected.onAction!.call();
                            },
                      child: Text(selected.actionLabel!),
                    ),
                ],
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
      final definition = _buildSectionDefinition(context, state, section);
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
              title: definition.title,
              child: SettingsSectionPage(
                title: definition.title,
                actionLabel: definition.actionLabel,
                onAction: definition.onAction,
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
    BuildContext context,
    SettingsState state,
    _SettingsSection section,
  ) {
    switch (section) {
      case _SettingsSection.model:
        final draft = _effectiveConfig(state);
        return SettingsSectionDefinition(
          icon: Icons.smart_toy_outlined,
          title: '模型配置',
          subtitle: draft.llmModel.trim().isEmpty
              ? 'Base URL、API Key、Model'
              : draft.llmModel.trim(),
          actionLabel: state.isSaving ? '保存中...' : '保存',
          onAction: state.isSaving ? null : _save,
          children: [
            ModelSettingsSection(
              config: draft,
              onChanged: _updateDraftConfig,
            ),
          ],
        );
      case _SettingsSection.bangumi:
        final draft = _effectiveConfig(state);
        return SettingsSectionDefinition(
          icon: Icons.api_outlined,
          title: 'Bangumi 设置',
          subtitle: draft.bangumiPrivateApiBaseUrl.trim().isEmpty
              ? 'API、OAuth、账号状态'
              : (state.bangumiProfile?.displayName ??
                    draft.bangumiPrivateApiBaseUrl.trim()),
          actionLabel: state.isSaving ? '保存中...' : '保存',
          onAction: state.isSaving ? null : _save,
          children: [
            BangumiSettingsSection(
              state: state,
              config: draft,
              onChanged: _updateDraftConfig,
              onRefresh: state.isSaving || state.isLoadingBangumiProfile
                  ? null
                  : _store.refreshBangumiProfile,
              onLogin: state.isSaving || state.isBangumiAuthorizing
                  ? null
                  : _startBangumiOAuthLogin,
              onLogout: state.isSaving || state.isBangumiAuthorizing
                  ? null
                  : _store.logoutBangumi,
            ),
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

  Future<void> _save() async {
    final config = _effectiveConfig(_store.value);
    await _store.save(config);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('配置已保存')));
    _hasSyncedInitialConfig = true;
  }

  AppConfig _effectiveConfig(SettingsState state) {
    return _draftConfig ?? state.config;
  }

  void _updateDraftConfig(AppConfig nextConfig) {
    setState(() {
      _draftConfig = nextConfig;
    });
  }

  Future<void> _startBangumiOAuthLogin() async {
    await _save();
    await _store.startBangumiOAuthLogin();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已打开浏览器，请完成 Bangumi 授权。')),
    );
  }

  Future<void> _clearImageCache() async {
    try {
      await _store.clearImageCache();
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
      await _store.clearAllCaches();
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
    required String title,
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
