import 'dart:convert';
import 'dart:io';

import '../../models/app_config.dart';

class FileConfigRepository {
  FileConfigRepository(this._file);

  final File _file;
  AppConfig? _cached;

  Future<AppConfig> load() async {
    if (_cached != null) {
      return _cached!;
    }
    if (!await _file.exists()) {
      _cached = AppConfig.defaults;
      return _cached!;
    }
    final text = await _file.readAsString();
    if (text.trim().isEmpty) {
      _cached = AppConfig.defaults;
      return _cached!;
    }
    _cached = AppConfig.fromJson(jsonDecode(text) as Map<String, dynamic>);
    return _cached!;
  }

  Future<void> save(AppConfig config) async {
    _cached = config;
    await _file.writeAsString(jsonEncode(config.toJson()));
  }
}
