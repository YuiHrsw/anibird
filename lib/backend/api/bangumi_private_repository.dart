import 'bangumi/bangumi_api_client.dart';
import '../models/paged_result.dart';
import '../models/episode.dart';
import '../models/subject.dart';
import '../models/bangumi_profile.dart';
import '../models/episode_comment.dart';
import '../models/subject_discussion.dart';
import '../models/subject_review.dart';
import '../models/timeline_item.dart';
import '../models/blog_entry.dart';
import '../models/blog_comment.dart';

class BangumiPrivateRepository {
  BangumiPrivateRepository(this._client);

  final BangumiApiClient _client;

  Future<BangumiProfile> getCurrentUser() async {
    final json = await _client.getJson('me');
    return BangumiProfile.fromJson(json);
  }

  Future<PagedResult<Subject>> getMySubjectCollections({
    required int type,
    int subjectType = 2,
    int limit = 20,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      'collections/subjects',
      queryParameters: {
        'subjectType': subjectType,
        'type': type,
        'limit': limit,
        'offset': offset,
      },
    );
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => Subject.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <Subject>[];
    return PagedResult<Subject>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: limit),
      offset: _asInt(json['offset'], fallback: offset),
      data: items,
    );
  }

  Future<List<EpisodeComment>> getEpisodeComments(int episodeId) async {
    final json = await _client.getJsonList('episodes/$episodeId/comments');
    return json
        .whereType<Map>()
        .map((item) => EpisodeComment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<PagedResult<Episode>> getSubjectEpisodes(
    int subjectId, {
    int? type,
    int limit = 1000,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      'subjects/$subjectId/episodes',
      queryParameters: {
        'type': type,
        'limit': limit,
        'offset': offset,
      },
    );
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => Episode.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <Episode>[];
    return PagedResult<Episode>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: limit),
      offset: _asInt(json['offset'], fallback: offset),
      data: items,
    );
  }

  Future<Episode> getEpisodeDetail(int episodeId) async {
    final json = await _client.getJson('episodes/$episodeId');
    return Episode.fromJson(json);
  }

  Future<PagedResult<SubjectComment>> getSubjectComments(
    int subjectId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      'subjects/$subjectId/comments',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => SubjectComment.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <SubjectComment>[];
    return PagedResult<SubjectComment>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: limit),
      offset: _asInt(json['offset'], fallback: offset),
      data: items,
    );
  }

  Future<PagedResult<SubjectTopic>> getSubjectTopics(
    int subjectId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      'subjects/$subjectId/topics',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => SubjectTopic.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <SubjectTopic>[];
    return PagedResult<SubjectTopic>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: limit),
      offset: _asInt(json['offset'], fallback: offset),
      data: items,
    );
  }

  Future<PagedResult<SubjectReview>> getSubjectReviews(
    int subjectId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      'subjects/$subjectId/reviews',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    final items =
        (json['data'] as List?)
            ?.whereType<Map>()
            .map((item) => SubjectReview.fromJson(item.cast<String, dynamic>()))
            .toList() ??
        const <SubjectReview>[];
    return PagedResult<SubjectReview>(
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: limit),
      offset: _asInt(json['offset'], fallback: offset),
      data: items,
    );
  }

  Future<List<TimelineItem>> getTimeline({
    String mode = 'friends',
    int limit = 20,
    int? until,
  }) async {
    final json = await _client.getJsonList(
      'timeline',
      queryParameters: {
        'mode': mode,
        'limit': limit,
        'until': until,
      },
    );
    return json
        .whereType<Map>()
        .map((item) => TimelineItem.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<BlogEntry> getBlogEntry(int entryId) async {
    final json = await _client.getJson('blogs/$entryId');
    return BlogEntry.fromJson(json);
  }

  Future<List<BlogComment>> getBlogComments(int entryId) async {
    final json = await _client.getJsonList('blogs/$entryId/comments');
    return json
        .whereType<Map>()
        .map((item) => BlogComment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
