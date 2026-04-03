import 'package:flutter/material.dart';

import '../../../backend/models/app_config.dart';

class ModelSettingsSection extends StatefulWidget {
  const ModelSettingsSection({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;

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
    _baseUrlController = TextEditingController(text: widget.config.llmBaseUrl);
    _apiKeyController = TextEditingController(text: widget.config.llmApiKey);
    _modelController = TextEditingController(text: widget.config.llmModel);
  }

  @override
  void didUpdateWidget(covariant ModelSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.llmBaseUrl != widget.config.llmBaseUrl &&
        _baseUrlController.text != widget.config.llmBaseUrl) {
      _baseUrlController.text = widget.config.llmBaseUrl;
    }
    if (oldWidget.config.llmApiKey != widget.config.llmApiKey &&
        _apiKeyController.text != widget.config.llmApiKey) {
      _apiKeyController.text = widget.config.llmApiKey;
    }
    if (oldWidget.config.llmModel != widget.config.llmModel &&
        _modelController.text != widget.config.llmModel) {
      _modelController.text = widget.config.llmModel;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _emitChanged() {
    widget.onChanged(
      widget.config.copyWith(
        llmBaseUrl: _baseUrlController.text,
        llmApiKey: _apiKeyController.text,
        llmModel: _modelController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('settings-base-url'),
          controller: _baseUrlController,
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Base URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('settings-api-key'),
          controller: _apiKeyController,
          onChanged: (_) => _emitChanged(),
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
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
