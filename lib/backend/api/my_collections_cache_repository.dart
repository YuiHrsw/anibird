import 'dart:convert';
import 'dart:io';

import '../models/subject.dart';

class MyCollectionsCacheRepository {
  MyCollectionsCacheRepository(this._file);

  final File _file;
  Map<int, List<Subject>>? _cached;
  Map<int, int>? _cachedTypeBySubjectId;

  Future<Map<int, List<Subject>>> loadAll() async {
    final cache = await _loadAll();
    return Map<int, List<Subject>>.unmodifiable({
      for (final entry in cache.entries)
        entry.key: List<Subject>.unmodifiable(entry.value),
    });
  }

  Future<List<Subject>> load(int type) async {
    final cache = await _loadAll();
    return cache[type] ?? const <Subject>[];
  }

  Future<Map<int, int>> loadSubjectTypeMap() async {
    await _loadAll();
    return Map<int, int>.unmodifiable(_cachedTypeBySubjectId ?? const <int, int>{});
  }

  Future<void> save(int type, List<Subject> items) async {
    final cache = await _loadAll();
    cache[type] = List<Subject>.unmodifiable(items);
    _cached = cache;
    _cachedTypeBySubjectId = _buildTypeBySubjectId(cache);
    await _file.writeAsString(
      jsonEncode({
        for (final entry in cache.entries)
          entry.key.toString(): entry.value
              .map((item) => item.toJson())
              .toList(growable: false),
      }),
    );
  }

  Future<void> clear() async {
    _cached = <int, List<Subject>>{};
    _cachedTypeBySubjectId = <int, int>{};
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  Future<Map<int, List<Subject>>> _loadAll() async {
    if (_cached != null) {
      return _cached!;
    }
    if (!await _file.exists()) {
      _cached = <int, List<Subject>>{};
      return _cached!;
    }
    final text = await _file.readAsString();
    if (text.trim().isEmpty) {
      _cached = <int, List<Subject>>{};
      return _cached!;
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      _cached = <int, List<Subject>>{};
      return _cached!;
    }

    _cached = <int, List<Subject>>{
      for (final entry in decoded.entries)
        int.tryParse(entry.key.toString()) ?? -1: (entry.value as List?)
                ?.whereType<Map>()
                .map((item) => Subject.fromJson(item.cast<String, dynamic>()))
                .toList(growable: false) ??
            const <Subject>[],
    }..remove(-1);
    _cachedTypeBySubjectId = _buildTypeBySubjectId(_cached!);
    return _cached!;
  }

  Map<int, int> _buildTypeBySubjectId(Map<int, List<Subject>> cache) {
    final result = <int, int>{};
    for (final entry in cache.entries) {
      for (final subject in entry.value) {
        result[subject.id] = entry.key;
      }
    }
    return result;
  }
}
