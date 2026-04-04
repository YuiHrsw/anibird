import 'dart:convert';
import 'dart:io';

import '../models/subject.dart';

class MyCollectionsCacheRepository {
  MyCollectionsCacheRepository(this._file);

  final File _file;
  Map<int, List<Subject>>? _cached;

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

  Future<void> save(int type, List<Subject> items) async {
    final cache = await _loadAll();
    cache[type] = List<Subject>.unmodifiable(items);
    _cached = cache;
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
    return _cached!;
  }
}
