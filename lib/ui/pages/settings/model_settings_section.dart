import 'package:flutter/material.dart';

import '../../../backend/models/agent_tool_config.dart';
import '../../state/settings_store.dart';

class ModelSettingsSection extends StatefulWidget {
  const ModelSettingsSection({super.key, required this.store});

  final SettingsStore store;

  @override
  State<ModelSettingsSection> createState() => _ModelSettingsSectionState();
}

class _ModelSettingsSectionState extends State<ModelSettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late Set<String> _enabledToolNames;
  late Set<String> _lastSyncedToolNames;

  @override
  void initState() {
    super.initState();
    final config = widget.store.value.config;
    _baseUrlController = TextEditingController(text: config.llmBaseUrl);
    _apiKeyController = TextEditingController(text: config.llmApiKey);
    _modelController = TextEditingController(text: config.llmModel);
    _enabledToolNames = {...config.enabledAgentToolNames};
    _lastSyncedToolNames = {...config.enabledAgentToolNames};
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = widget.store.value.config;
    final next = current.copyWith(
      llmBaseUrl: _baseUrlController.text,
      llmApiKey: _apiKeyController.text,
      llmModel: _modelController.text,
      enabledAgentToolNames: availableAgentToolConfigs
          .map((item) => item.name)
          .where(_enabledToolNames.contains)
          .toList(growable: false),
    );
    await widget.store.save(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('配置已保存')));
  }

  Future<void> _saveEnabledTools() async {
    final current = widget.store.value.config;
    final next = current.copyWith(
      enabledAgentToolNames: availableAgentToolConfigs
          .map((item) => item.name)
          .where(_enabledToolNames.contains)
          .toList(growable: false),
    );
    await widget.store.save(next);
    _lastSyncedToolNames = {...next.enabledAgentToolNames};
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: widget.store,
      builder: (context, state, _) {
        final availableToolNames = availableAgentToolConfigs
            .map((item) => item.name)
            .toSet();
        final nextEnabledToolNames = state.config.enabledAgentToolNames
            .where(availableToolNames.contains)
            .toSet();
        if (!_sameStringSet(_lastSyncedToolNames, nextEnabledToolNames)) {
          _enabledToolNames = nextEnabledToolNames;
          _lastSyncedToolNames = nextEnabledToolNames;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: state.isSaving
                    ? null
                    : () async {
                        await _save();
                      },
                child: Text(state.isSaving ? '保存中...' : '保存'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-base-url'),
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-api-key'),
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-model'),
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Agent 工具', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '控制当前请求发给 Agent 的工具列表。关闭后，模型本轮将无法调用对应工具。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final tool in availableAgentToolConfigs)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tool.title),
                subtitle: Text(tool.description),
                value: _enabledToolNames.contains(tool.name),
                onChanged: state.isSaving
                    ? null
                    : (enabled) async {
                        final previous = {..._enabledToolNames};
                        setState(() {
                          if (enabled) {
                            _enabledToolNames.add(tool.name);
                          } else {
                            _enabledToolNames.remove(tool.name);
                          }
                        });
                        try {
                          await _saveEnabledTools();
                        } catch (_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _enabledToolNames = previous;
                          });
                        }
                      },
              ),
          ],
        );
      },
    );
  }
}

bool _sameStringSet(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final item in left) {
    if (!right.contains(item)) {
      return false;
    }
  }
  return true;
}
