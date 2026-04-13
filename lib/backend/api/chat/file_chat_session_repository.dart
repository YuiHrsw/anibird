import 'dart:convert';
import 'dart:io';

import '../../models/chat_session.dart';

class FileChatSessionRepository {
  FileChatSessionRepository(this._directory);

  final Directory _directory;

  Future<List<ChatSession>> loadAll() async {
    await _ensureDirectory();
    final files = _directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false);

    final sessions = <ChatSession>[];
    for (final file in files) {
      try {
        final text = await file.readAsString();
        if (text.trim().isEmpty) {
          continue;
        }
        final decoded = jsonDecode(text);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        sessions.add(ChatSession.fromJson(decoded));
      } catch (_) {
        continue;
      }
    }

    sessions.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List<ChatSession>.unmodifiable(sessions);
  }

  Future<void> save(ChatSession session) async {
    await _ensureDirectory();
    final file = _fileForSession(session.id);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<void> delete(String sessionId) async {
    final file = _fileForSession(sessionId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _ensureDirectory() async {
    if (!await _directory.exists()) {
      await _directory.create(recursive: true);
    }
  }

  File _fileForSession(String sessionId) =>
      File('${_directory.path}/$sessionId.json');
}
