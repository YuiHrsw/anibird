import 'bangumi/bangumi_api_client.dart';
import '../models/browse_query.dart';
import '../models/episode.dart';
import '../models/paged_result.dart';
import '../models/related_character.dart';
import '../models/related_person.dart';
import '../models/search_query.dart';
import '../models/subject.dart';

class BangumiRepository {
  BangumiRepository(this._client);

  final BangumiApiClient _client;

  Future<PagedResult<Subject>> browseSubjects(BrowseQuery query) async {
    final json = await _client.getJson(
      '/v0/subjects',
      queryParameters: {
        'type': query.type,
        'sort': query.sort,
        'limit': query.limit,
        'offset': query.offset,
        if (query.year != null) 'year': query.year,
        if (query.month != null) 'month': query.month,
      },
    );
    return _toPagedSubjects(json);
  }

  Future<List<RelatedCharacter>> getRelatedCharacters(int subjectId) async {
    final json = await _client.getJsonList('/v0/subjects/$subjectId/characters');
    return json
        .whereType<Map>()
        .map((item) => RelatedCharacter.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<RelatedPerson>> getRelatedPersons(int subjectId) async {
    final json = await _client.getJsonList('/v0/subjects/$subjectId/persons');
    return json
        .whereType<Map>()
        .map((item) => RelatedPerson.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<Subject>> getRelatedSubjects(int subjectId) async {
    final json = await _client.getJsonList('/v0/subjects/$subjectId/subjects');
    return json
        .whereType<Map>()
        .map((item) => Subject.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<PagedResult<Episode>> getEpisodes(
    int subjectId, {
    int? type,
    int limit = 100,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      '/v0/episodes',
      queryParameters: {
        'subject_id': subjectId,
        'type': type,
        'limit': limit,
        'offset': offset,
      },
    );
    return _toPagedEpisodes(json);
  }

  Future<Episode> getEpisodeDetail(int episodeId) async {
    final json = await _client.getJson('/v0/episodes/$episodeId');
    return Episode.fromJson(json);
  }

  Future<Subject> getSubjectDetail(int subjectId) async {
    final json = await _client.getJson('/v0/subjects/$subjectId');
    return Subject.fromJson(json);
  }

  Future<PagedResult<Subject>> searchSubjects(SearchQuery query) async {
    final json = await _client.postJson(
      '/v0/search/subjects',
      queryParameters: {'limit': query.limit, 'offset': query.offset},
      body: query.toJson(),
    );
    return _toPagedSubjects(json);
  }

  PagedResult<Subject> _toPagedSubjects(Map<String, dynamic> json) {
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => Subject.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <Subject>[];
    return PagedResult<Subject>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit']),
      offset: _asInt(json['offset']),
      data: items,
    );
  }

  PagedResult<Episode> _toPagedEpisodes(Map<String, dynamic> json) {
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => Episode.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <Episode>[];
    return PagedResult<Episode>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit']),
      offset: _asInt(json['offset']),
      data: items,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
