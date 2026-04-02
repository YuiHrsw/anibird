import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../backend/models/app_config.dart';
import '../state/settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _userAgentController;
  late final SettingsStore _store;
  bool _hasBoundStore = false;
  bool _debugTrace = true;
  bool _hasSyncedInitialConfig = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _userAgentController = TextEditingController();
  }

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
      _sync(_store.value.config);
      _hasSyncedInitialConfig = true;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _userAgentController.dispose();
    super.dispose();
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
              _sync(state.config);
              _hasSyncedInitialConfig = true;
            });
          });
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Text('模型配置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('settings-base-url'),
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('settings-api-key'),
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('settings-model'),
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Bangumi 配置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('settings-user-agent'),
              controller: _userAgentController,
              decoration: const InputDecoration(
                labelText: 'Bangumi User-Agent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _debugTrace,
              title: const Text('显示工具调用轨迹'),
              onChanged: (value) {
                setState(() {
                  _debugTrace = value;
                });
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.isSaving ? null : _save,
              child: Text(state.isSaving ? '保存中...' : '保存配置'),
            ),
          ],
        );
      },
    );
  }

  void _sync(AppConfig config) {
    _baseUrlController.text = config.llmBaseUrl;
    _apiKeyController.text = config.llmApiKey;
    _modelController.text = config.llmModel;
    _userAgentController.text = config.bangumiUserAgent;
    _debugTrace = config.debugShowToolTrace;
  }

  Future<void> _save() async {
    final config = AppConfig(
      llmBaseUrl: _baseUrlController.text.trim(),
      llmApiKey: _apiKeyController.text.trim(),
      llmModel: _modelController.text.trim(),
      bangumiUserAgent: _userAgentController.text.trim(),
      debugShowToolTrace: _debugTrace,
    );
    await _store.save(config);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('配置已保存')));
    _hasSyncedInitialConfig = true;
  }
}
