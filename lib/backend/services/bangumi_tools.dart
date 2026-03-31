import '../api/bangumi_repository.dart';
import '../models/browse_query.dart';
import '../models/search_query.dart';
import '../models/subject.dart';
import '../models/tool.dart';

const int _defaultListLimit = 6;
const int _defaultBrowseLimit = 8;
const int _defaultCastLimit = 6;
const int _defaultEpisodeLimit = 10;
const int _defaultRecommendationLimit = 5;
const int _maxListLimit = 12;

class SearchAnimeTool implements AgentTool {
  SearchAnimeTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'search_anime',
    description: '搜索动画条目，适合根据题材、风格、年代和关键词找候选作品。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'keyword': {'type': 'string'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'meta_tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'sort': {
          'type': 'string',
          'enum': ['match', 'heat', 'rank', 'score'],
        },
        'limit': {'type': 'integer'},
      },
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.searchSubjects(
      SearchQuery(
        keyword: input['keyword']?.toString() ?? '',
        tags: _asStringList(input['tags']),
        metaTags: _asStringList(input['meta_tags']),
        sort: input['sort']?.toString() ?? 'match',
        limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      ),
    );
    return ToolResult(
      toolName: definition.name,
      summary: '找到 ${result.data.length} 个候选条目。',
      payload: {'results': result.data.map((item) => item.toJson()).toList()},
      observationText: _payloadObservation(
        label: 'Search results',
        payload: {'results': result.data.map((item) => item.toJson()).toList()},
      ),
      subjects: result.data,
    );
  }
}

class SearchSubjectsByTagsTool implements AgentTool {
  SearchSubjectsByTagsTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'search_subjects_by_tags',
    description: '按 tag 和 meta tag 搜索动画条目，适合查找题材更相关的候选作品。可选 keyword 用于补充限定词。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'meta_tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'keyword': {'type': 'string'},
        'sort': {
          'type': 'string',
          'enum': ['match', 'heat', 'rank', 'score'],
        },
        'limit': {'type': 'integer'},
      },
      'required': ['tags'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.searchSubjects(
      SearchQuery(
        keyword: input['keyword']?.toString() ?? '',
        tags: _asStringList(input['tags']),
        metaTags: _asStringList(input['meta_tags']),
        sort: input['sort']?.toString() ?? 'match',
        limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      ),
    );
    return ToolResult(
      toolName: definition.name,
      summary: '按标签找到 ${result.data.length} 个更相关的候选条目。',
      payload: {'results': result.data.map((item) => item.toJson()).toList()},
      observationText: _payloadObservation(
        label: 'Tagged search results',
        payload: {'results': result.data.map((item) => item.toJson()).toList()},
      ),
      subjects: result.data,
    );
  }
}

class GetSubjectDetailTool implements AgentTool {
  GetSubjectDetailTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_detail',
    description: '按 Bangumi subject id 获取条目详情。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final subject = await _repository.getSubjectDetail(
      _asInt(input['subject_id']),
    );
    final payload = {'subject': subject.toJson()};
    return ToolResult(
      toolName: definition.name,
      summary: '已获取《${subject.displayName}》详情。',
      payload: payload,
      observationText: _payloadObservation(label: 'Subject detail', payload: payload),
      subjects: [subject],
    );
  }
}

class GetRelatedSubjectsTool implements AgentTool {
  GetRelatedSubjectsTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_related_subjects',
    description: '获取某个条目的关联作品，用于找续作、前传或相似内容。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final subjects =
        (await _repository.getRelatedSubjects(_asInt(input['subject_id'])))
            .take(_boundedLimit(input['limit'], fallback: _defaultListLimit))
            .toList(growable: false);
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${subjects.length} 个关联条目。',
      payload: {'results': subjects.map((item) => item.toJson()).toList()},
      observationText: _payloadObservation(
        label: 'Related subjects',
        payload: {'results': subjects.map((item) => item.toJson()).toList()},
      ),
      subjects: subjects,
    );
  }
}

class GetSubjectCastTool implements AgentTool {
  GetSubjectCastTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_cast',
    description: '获取条目的角色和制作人员信息，用于解释看点和阵容。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'character_limit': {'type': 'integer'},
        'person_limit': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final subjectId = _asInt(input['subject_id']);
    final characters = (await _repository.getRelatedCharacters(subjectId))
        .take(
          _boundedLimit(input['character_limit'], fallback: _defaultCastLimit),
        )
        .toList(growable: false);
    final persons = (await _repository.getRelatedPersons(subjectId))
        .take(_boundedLimit(input['person_limit'], fallback: _defaultCastLimit))
        .toList(growable: false);
    final payload = {
      'characters': characters.map((item) => item.toJson()).toList(),
      'persons': persons.map((item) => item.toJson()).toList(),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${characters.length} 个角色和 ${persons.length} 位制作相关人物。',
      payload: payload,
      observationText: _payloadObservation(label: 'Subject cast', payload: payload),
    );
  }
}

class GetSubjectEpisodesTool implements AgentTool {
  GetSubjectEpisodesTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_episodes',
    description: '获取某个条目的单集列表与每集简短介绍，适合分析剧情推进和集数结构。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'type': {'type': 'integer'},
        'limit': {'type': 'integer'},
        'offset': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.getEpisodes(
      _asInt(input['subject_id']),
      type: input['type'] == null ? null : _asInt(input['type']),
      limit: _boundedLimit(input['limit'], fallback: _defaultEpisodeLimit),
      offset: _asInt(input['offset']),
    );
    final payload = {
      'episodes': result.data.map((item) => item.toJson()).toList(growable: false),
      'total': result.total,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${result.data.length} 集单集信息。',
      payload: payload,
      observationText: _payloadObservation(label: 'Episodes', payload: payload),
    );
  }
}

class GetEpisodeDetailTool implements AgentTool {
  GetEpisodeDetailTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_episode_detail',
    description: '按 episode id 获取单集详情，包括单集简介、时长、播出时间和评论数。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'episode_id': {'type': 'integer'},
      },
      'required': ['episode_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final episode = await _repository.getEpisodeDetail(_asInt(input['episode_id']));
    final payload = {'episode': episode.toJson()};
    return ToolResult(
      toolName: definition.name,
      summary: '已获取单集《${episode.displayName}》详情。',
      payload: payload,
      observationText: _payloadObservation(label: 'Episode detail', payload: payload),
    );
  }
}

class BrowseSubjectsTool implements AgentTool {
  BrowseSubjectsTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'browse_subjects',
    description: '浏览动画条目榜单，适合在缺少明确关键词时找高分热门作品。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'sort': {'type': 'string'},
        'year': {'type': 'integer'},
        'month': {'type': 'integer'},
        'limit': {'type': 'integer'},
      },
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.browseSubjects(
      BrowseQuery(
        sort: input['sort']?.toString() ?? 'rank',
        year: input['year'] as int?,
        month: input['month'] as int?,
        limit: _boundedLimit(input['limit'], fallback: _defaultBrowseLimit),
      ),
    );
    return ToolResult(
      toolName: definition.name,
      summary: '浏览结果共返回 ${result.data.length} 个条目。',
      payload: {'results': result.data.map((item) => item.toJson()).toList()},
      observationText: _payloadObservation(
        label: 'Browse results',
        payload: {'results': result.data.map((item) => item.toJson()).toList()},
      ),
      subjects: result.data,
    );
  }
}

class PresentRecommendationsTool implements AgentTool {
  PresentRecommendationsTool(this._repository);

  final BangumiRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'present_recommendations',
    description: '在回答末尾显式提交最终要展示给用户的推荐条目列表。请只传你最终决定推荐的 subject_id，顺序就是展示顺序。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_ids': {
          'type': 'array',
          'items': {'type': 'integer'},
        },
        'limit': {'type': 'integer'},
      },
      'required': ['subject_ids'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final ids =
        (input['subject_ids'] as List?)
            ?.map((item) => _asInt(item))
            .where((item) => item > 0)
            .toList(growable: false) ??
        const <int>[];
    final limit = _boundedLimit(
      input['limit'],
      fallback: _defaultRecommendationLimit,
    );
    final selectedIds = ids.take(limit).toList(growable: false);
    final subjects = <Subject>[];
    final resolved = <Map<String, dynamic>>[];
    for (final id in selectedIds) {
      final subject = await _repository.getSubjectDetail(id);
      subjects.add(subject);
      resolved.add(subject.toJson());
    }
    final payload = {
      'ok': true,
      'submitted_subject_ids': selectedIds,
      'resolved_count': subjects.length,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '已提交 ${subjects.length} 个最终推荐条目用于展示。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Present recommendations result',
        payload: payload,
      ),
      subjects: subjects,
    );
  }
}

List<AgentTool> buildBangumiTools(BangumiRepository repository) {
  return [
    SearchAnimeTool(repository),
    SearchSubjectsByTagsTool(repository),
    GetSubjectDetailTool(repository),
    GetRelatedSubjectsTool(repository),
    GetSubjectCastTool(repository),
    GetSubjectEpisodesTool(repository),
    GetEpisodeDetailTool(repository),
    BrowseSubjectsTool(repository),
    PresentRecommendationsTool(repository),
  ];
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

int _boundedLimit(Object? value, {required int fallback}) {
  final parsed = _asInt(value, fallback: fallback);
  if (parsed <= 0) {
    return fallback;
  }
  if (parsed > _maxListLimit) {
    return _maxListLimit;
  }
  return parsed;
}

List<String> _asStringList(Object? value) {
  return (value as List?)
          ?.map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false) ??
      const <String>[];
}

String _payloadObservation({
  required String label,
  required Map<String, dynamic> payload,
}) {
  return formatStructuredData(payload, label: label);
}
