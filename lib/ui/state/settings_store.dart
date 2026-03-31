import 'package:flutter/foundation.dart';

import '../../backend/api/config/file_config_repository.dart';
import '../../backend/models/app_config.dart';

@immutable
class SettingsState {
  const SettingsState({
    this.config = AppConfig.defaults,
    this.isLoaded = false,
    this.isSaving = false,
    this.error,
  });

  final AppConfig config;
  final bool isLoaded;
  final bool isSaving;
  final String? error;

  SettingsState copyWith({
    AppConfig? config,
    bool? isLoaded,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      config: config ?? this.config,
      isLoaded: isLoaded ?? this.isLoaded,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SettingsStore extends ValueNotifier<SettingsState> {
  SettingsStore(this._repository) : super(const SettingsState());

  final FileConfigRepository _repository;

  Future<void> load() async {
    try {
      final config = await _repository.load();
      value = value.copyWith(config: config, isLoaded: true, clearError: true);
    } catch (error) {
      value = value.copyWith(
        isLoaded: true,
        error: error.toString(),
      );
    }
  }

  Future<void> save(AppConfig config) async {
    value = value.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.save(config);
      value = value.copyWith(
        config: config,
        isLoaded: true,
        isSaving: false,
      );
    } catch (error) {
      value = value.copyWith(isSaving: false, error: error.toString());
      rethrow;
    }
  }
}
