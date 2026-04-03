import 'package:flutter/material.dart';

import '../../state/settings_store.dart';

class ModelSettingsSection extends StatefulWidget {
  const ModelSettingsSection({
    super.key,
    required this.store,
  });

  final SettingsStore store;

  @override
  State<ModelSettingsSection> createState() => _ModelSettingsSectionState();
}

class _ModelSettingsSectionState extends State<ModelSettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    final config = widget.store.value.config;
    _baseUrlController = TextEditingController(text: config.llmBaseUrl);
    _apiKeyController = TextEditingController(text: config.llmApiKey);
    _modelController = TextEditingController(text: config.llmModel);
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
    );
    await widget.store.save(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('配置已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: widget.store,
      builder: (context, state, _) {
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
          ],
        );
      },
    );
  }
}
