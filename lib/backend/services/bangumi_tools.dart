import '../api/bangumi/bangumi_private_repository.dart';
import '../api/bangumi/bangumi_repository.dart';
import '../api/my_collections_cache_repository.dart';
import '../models/bangumi_profile.dart';
import '../models/browse_query.dart';
import '../models/blog_comment.dart';
import '../models/blog_entry.dart';
import '../models/episode_comment.dart';
import '../models/search_query.dart';
import '../models/subject.dart';
import '../models/subject_discussion.dart';
import '../models/subject_review.dart';
import '../models/timeline_item.dart';
import '../models/tool.dart';

const int _defaultListLimit = 6;
const int _defaultBrowseLimit = 8;
const int _defaultCastLimit = 6;
const int _defaultEpisodeLimit = 10;
const int _defaultRecommendationLimit = 5;
const int _maxListLimit = 12;

class SubjectSnapshotCache {
  final Map<int, Subject> _subjectsById = <int, Subject>{};

  void rememberAll(Iterable<Subject> subjects) {
    for (final subject in subjects) {
      _subjectsById[subject.id] = subject;
    }
  }

  Subject? get(int id) => _subjectsById[id];
}

class SearchAnimeTool implements AgentTool {
  SearchAnimeTool(this._repository, this._cache, this._collectionsCacheRepository);

  final BangumiPrivateRepository _repository;
  final SubjectSnapshotCache _cache;
  final MyCollectionsCacheRepository? _collectionsCacheRepository;

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
    final collectionTypeBySubjectId =
        await _collectionsCacheRepository?.loadSubjectTypeMap() ??
        const <int, int>{};
    _cache.rememberAll(result.data);
    final payload = {
      'results': result.data
          .map((item) => _searchSubjectToToolJson(item, collectionTypeBySubjectId))
          .toList(growable: false),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '找到 ${result.data.length} 个候选条目。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Search results',
        payload: payload,
      ),
      subjects: result.data,
    );
  }
}

class SearchSubjectsByTagsTool implements AgentTool {
  SearchSubjectsByTagsTool(
    this._repository,
    this._cache,
    this._collectionsCacheRepository,
  );

  final BangumiPrivateRepository _repository;
  final SubjectSnapshotCache _cache;
  final MyCollectionsCacheRepository? _collectionsCacheRepository;

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
    final collectionTypeBySubjectId =
        await _collectionsCacheRepository?.loadSubjectTypeMap() ??
        const <int, int>{};
    _cache.rememberAll(result.data);
    final payload = {
      'results': result.data
          .map((item) => _searchSubjectToToolJson(item, collectionTypeBySubjectId))
          .toList(growable: false),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '按标签找到 ${result.data.length} 个更相关的候选条目。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Tagged search results',
        payload: payload,
      ),
      subjects: result.data,
    );
  }
}

class GetSubjectDetailTool implements AgentTool {
  GetSubjectDetailTool(this._repository, this._cache);

  final BangumiPrivateRepository _repository;
  final SubjectSnapshotCache _cache;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_detail',
    description:
        '按 Bangumi subject id 获取条目详情。如果能看到用户的收藏状态, 那么最好不要给用户推荐已看过/抛弃的番剧',
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
    _cache.rememberAll([subject]);
    final payload = {'subject': _subjectDetailToJson(subject)};
    return ToolResult(
      toolName: definition.name,
      summary: '已获取《${subject.displayName}》详情。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Subject detail',
        payload: payload,
      ),
      subjects: [subject],
    );
  }
}

class GetRelatedSubjectsTool implements AgentTool {
  GetRelatedSubjectsTool(this._repository, this._cache);

  final BangumiRepository _repository;
  final SubjectSnapshotCache _cache;

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
    _cache.rememberAll(subjects);
    final payload = {
      'results': subjects.map(_subjectToToolJson).toList(growable: false),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${subjects.length} 个关联条目。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Related subjects',
        payload: payload,
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
      observationText: _payloadObservation(
        label: 'Subject cast',
        payload: payload,
      ),
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
      'episodes': result.data
          .map((item) => item.toJson())
          .toList(growable: false),
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
    final episode = await _repository.getEpisodeDetail(
      _asInt(input['episode_id']),
    );
    final payload = {'episode': episode.toJson()};
    return ToolResult(
      toolName: definition.name,
      summary: '已获取单集《${episode.displayName}》详情。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Episode detail',
        payload: payload,
      ),
    );
  }
}

class BrowseSubjectsTool implements AgentTool {
  BrowseSubjectsTool(this._repository, this._cache);

  final BangumiRepository _repository;
  final SubjectSnapshotCache _cache;

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
    _cache.rememberAll(result.data);
    final payload = {
      'results': result.data.map(_subjectToToolJson).toList(growable: false),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '浏览结果共返回 ${result.data.length} 个条目。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Browse results',
        payload: payload,
      ),
      subjects: result.data,
    );
  }
}

class GetMyProfileTool implements AgentTool {
  GetMyProfileTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_my_profile',
    description: '读取当前登录 Bangumi 用户资料。',
    inputSchema: {'type': 'object', 'properties': {}},
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final profile = await _repository.getCurrentUser();
    final payload = {'profile': _profileToJson(profile)};
    return ToolResult(
      toolName: definition.name,
      summary: '已读取当前登录用户资料。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'My profile',
        payload: payload,
      ),
    );
  }
}

class GetMyCollectionsTool implements AgentTool {
  GetMyCollectionsTool(this._repository, this._cache);

  final BangumiPrivateRepository _repository;
  final SubjectSnapshotCache _cache;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_my_collections',
    description:
        '读取当前账号的动画收藏列表，可按收藏状态筛选。type 含义：1=想看，2=看过，3=在看，4=搁置，5=抛弃；默认 3=在看。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'integer',
          'description': '收藏状态：1=想看，2=看过，3=在看，4=搁置，5=抛弃。',
        },
        'limit': {'type': 'integer'},
        'offset': {'type': 'integer'},
      },
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.getMySubjectCollections(
      type: _asInt(input['type'], fallback: 3),
      limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      offset: _asInt(input['offset']),
    );
    _cache.rememberAll(result.data);
    final payload = {
      'results': result.data
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'name_cn': item.nameCn,
              'type': _collectionTypeLabel(
                item.interest?.type ?? _asInt(input['type'], fallback: 3),
              ),
            },
          )
          .toList(growable: false),
      'total': result.total,
      'offset': result.offset,
      'limit': result.limit,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${result.data.length} 个我的收藏条目。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'My collections',
        payload: payload,
      ),
      subjects: result.data,
    );
  }
}

class GetEpisodeCommentsTool implements AgentTool {
  GetEpisodeCommentsTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_episode_comments',
    description: '读取单集评论和回复。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'episode_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
      },
      'required': ['episode_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final comments =
        (await _repository.getEpisodeComments(_asInt(input['episode_id'])))
            .take(_boundedLimit(input['limit'], fallback: _defaultListLimit))
            .map(_episodeCommentToJson)
            .toList(growable: false);
    final payload = {'results': comments};
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${comments.length} 条单集评论。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Episode comments',
        payload: payload,
      ),
    );
  }
}

class GetSubjectCommentsTool implements AgentTool {
  GetSubjectCommentsTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_comments',
    description: '读取条目短评和吐槽。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
        'offset': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.getSubjectComments(
      _asInt(input['subject_id']),
      limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      offset: _asInt(input['offset']),
    );
    final payload = {
      'results': result.data.map(_subjectCommentToJson).toList(growable: false),
      'total': result.total,
      'offset': result.offset,
      'limit': result.limit,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${result.data.length} 条条目评论。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Subject comments',
        payload: payload,
      ),
    );
  }
}

class GetSubjectTopicsTool implements AgentTool {
  GetSubjectTopicsTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_topics',
    description: '读取条目讨论主题。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
        'offset': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.getSubjectTopics(
      _asInt(input['subject_id']),
      limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      offset: _asInt(input['offset']),
    );
    final payload = {
      'results': result.data.map(_subjectTopicToJson).toList(growable: false),
      'total': result.total,
      'offset': result.offset,
      'limit': result.limit,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${result.data.length} 个讨论主题。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Subject topics',
        payload: payload,
      ),
    );
  }
}

class GetSubjectReviewsTool implements AgentTool {
  GetSubjectReviewsTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_subject_reviews',
    description: '读取条目的长评摘要。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'subject_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
        'offset': {'type': 'integer'},
      },
      'required': ['subject_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final result = await _repository.getSubjectReviews(
      _asInt(input['subject_id']),
      limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      offset: _asInt(input['offset']),
    );
    final payload = {
      'results': result.data.map(_subjectReviewToJson).toList(growable: false),
      'total': result.total,
      'offset': result.offset,
      'limit': result.limit,
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${result.data.length} 条长评摘要。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Subject reviews',
        payload: payload,
      ),
    );
  }
}

class GetTimelineTool implements AgentTool {
  GetTimelineTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_timeline',
    description: '读取 Bangumi 时间线动态。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'mode': {
          'type': 'string',
          'enum': ['friends', 'all'],
        },
        'limit': {'type': 'integer'},
        'until': {'type': 'integer'},
      },
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final items = await _repository.getTimeline(
      mode: input['mode']?.toString() ?? 'friends',
      limit: _boundedLimit(input['limit'], fallback: _defaultListLimit),
      until: input['until'] == null ? null : _asInt(input['until']),
    );
    final payload = {
      'results': items.map(_timelineItemToJson).toList(growable: false),
    };
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${items.length} 条时间线动态。',
      payload: payload,
      observationText: _payloadObservation(label: 'Timeline', payload: payload),
    );
  }
}

class GetBlogEntryTool implements AgentTool {
  GetBlogEntryTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_blog_entry',
    description: '读取日志正文内容。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'entry_id': {'type': 'integer'},
      },
      'required': ['entry_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final entry = await _repository.getBlogEntry(_asInt(input['entry_id']));
    final payload = {'entry': _blogEntryToJson(entry)};
    return ToolResult(
      toolName: definition.name,
      summary: '已获取日志《${entry.title}》详情。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Blog entry',
        payload: payload,
      ),
    );
  }
}

class GetBlogCommentsTool implements AgentTool {
  GetBlogCommentsTool(this._repository);

  final BangumiPrivateRepository _repository;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'get_blog_comments',
    description: '读取日志评论和回复。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'entry_id': {'type': 'integer'},
        'limit': {'type': 'integer'},
      },
      'required': ['entry_id'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final comments =
        (await _repository.getBlogComments(_asInt(input['entry_id'])))
            .take(_boundedLimit(input['limit'], fallback: _defaultListLimit))
            .map(_blogCommentToJson)
            .toList(growable: false);
    final payload = {'results': comments};
    return ToolResult(
      toolName: definition.name,
      summary: '获取到 ${comments.length} 条日志评论。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Blog comments',
        payload: payload,
      ),
    );
  }
}

class MarkFinalAnswerStartTool implements AgentTool {
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'mark_final_answer_start',
    description: '''
标记从这里开始进入最终给用户展示的答案区。
请在开始输出最终答案正文之前调用。
如果后续再次调用本工具，则应以前一次调用后的内容视为旧答案，以最后一次调用后的内容为准。
''',
    inputSchema: {'type': 'object', 'properties': {}},
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    const payload = {'ok': true, 'marked': true};
    return const ToolResult(
      toolName: 'mark_final_answer_start',
      summary: '已标记最终答案开始位置。',
      payload: payload,
      observationText: 'Final answer start marked.',
    );
  }
}

class PresentRecommendationsTool implements AgentTool {
  PresentRecommendationsTool(this._cache);

  final SubjectSnapshotCache _cache;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'set_recommendations',
    description: '''
建议在开始回答之前提前调用此工具, 以避免向用户展示多余的调用记录, 同时也有助于提前解决错误

如果你希望在回答下方展示推荐卡片以方便用户快速跳转，可以调用 set_recommendations, 并按展示顺序传入 subject_id。
请只传你最终决定推荐的 subject_id, 顺序就是展示顺序.
''',
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
    final cachedSubjects = <Subject>[];
    final unresolvedSubjectIds = <int>[];
    for (final id in selectedIds) {
      final cached = _cache.get(id);
      if (cached != null) {
        cachedSubjects.add(cached);
        continue;
      }
      unresolvedSubjectIds.add(id);
    }
    final payload = {
      'ok': true,
      'submitted_subject_ids': selectedIds,
      'resolved_count': cachedSubjects.length,
      'unresolved_subject_ids': unresolvedSubjectIds,
    };
    return ToolResult(
      toolName: definition.name,
      summary: unresolvedSubjectIds.isEmpty
          ? '已提交 ${cachedSubjects.length} 个最终推荐条目用于展示。'
          : '已提交 ${selectedIds.length} 个最终推荐条目，卡片内容将异步补全。',
      payload: payload,
      observationText: _payloadObservation(
        label: 'Present recommendations result',
        payload: payload,
      ),
      subjects: cachedSubjects,
      recommendationSubjectIds: selectedIds,
    );
  }
}

List<AgentTool> buildBangumiTools(
  BangumiRepository repository,
  BangumiPrivateRepository privateRepository,
  MyCollectionsCacheRepository? myCollectionsCacheRepository,
) {
  final cache = SubjectSnapshotCache();
  return [
    SearchAnimeTool(privateRepository, cache, myCollectionsCacheRepository),
    SearchSubjectsByTagsTool(
      privateRepository,
      cache,
      myCollectionsCacheRepository,
    ),
    GetSubjectDetailTool(privateRepository, cache),
    GetRelatedSubjectsTool(repository, cache),
    GetSubjectCastTool(repository),
    GetSubjectEpisodesTool(repository),
    GetEpisodeDetailTool(repository),
    BrowseSubjectsTool(repository, cache),
    GetMyProfileTool(privateRepository),
    GetMyCollectionsTool(privateRepository, cache),
    GetEpisodeCommentsTool(privateRepository),
    GetSubjectCommentsTool(privateRepository),
    GetSubjectTopicsTool(privateRepository),
    GetSubjectReviewsTool(privateRepository),
    GetTimelineTool(privateRepository),
    GetBlogEntryTool(privateRepository),
    GetBlogCommentsTool(privateRepository),
    MarkFinalAnswerStartTool(),
    PresentRecommendationsTool(cache),
  ];
}

Map<String, dynamic> _profileToJson(BangumiProfile value) {
  return {
    'id': value.id,
    'username': value.username,
    'nickname': value.nickname,
    'avatar': value.avatar,
    'sign': value.sign,
    'group': value.group,
    'joinedAt': value.joinedAt,
    'site': value.site,
    'location': value.location,
    'permissions': {'subjectWikiEdit': value.permissions.subjectWikiEdit},
  };
}

Map<String, dynamic> _subjectDiscussionUserToJson(
  SubjectDiscussionUser? value,
) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  return {
    'id': value.id,
    'username': value.username,
    'nickname': value.nickname,
    'avatar': value.avatar,
  };
}

Map<String, dynamic> _subjectCommentToJson(SubjectComment value) {
  return {
    'type': _collectionTypeLabel(value.type),
    'rate': value.rate,
    'comment': value.comment,
  };
}

Map<String, dynamic> _subjectTopicToJson(SubjectTopic value) {
  return {
    'id': value.id,
    'title': value.title,
    'creatorId': value.creatorId,
    'creator': _subjectDiscussionUserToJson(value.creator),
    'parentId': value.parentId,
    'replyCount': value.replyCount,
    'createdAt': value.createdAt,
    'updatedAt': value.updatedAt,
    'state': value.state,
    'display': value.display,
  };
}

Map<String, dynamic> _subjectReviewToJson(SubjectReview value) {
  return {
    'id': value.id,
    'title': value.entry.title,
    'summary': value.entry.summary,
  };
}

Map<String, dynamic> _episodeCommentToJson(EpisodeComment value) {
  return {'content': value.content};
}

Map<String, dynamic> _timelineUserToJson(TimelineUser? value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  return {
    'id': value.id,
    'username': value.username,
    'nickname': value.nickname,
    'avatar': value.avatar,
  };
}

Map<String, dynamic> _timelineSubjectToJson(TimelineSubjectRef value) {
  return {
    'id': value.id,
    'name': value.name,
    'nameCn': value.nameCn,
    'image': value.image,
  };
}

Map<String, dynamic> _timelineItemToJson(TimelineItem value) {
  return {
    'id': value.id,
    'uid': value.uid,
    'cat': value.cat,
    'type': value.type,
    'batch': value.batch,
    'replies': value.replies,
    'createdAt': value.createdAt,
    'user': _timelineUserToJson(value.user),
    'sourceName': value.sourceName,
    'sourceUrl': value.sourceUrl,
    'summary': value.summary,
    'detail': value.detail,
    'subjects': value.subjects
        .map(_timelineSubjectToJson)
        .toList(growable: false),
  };
}

Map<String, dynamic> _subjectDetailToJson(Subject value) {
  final data = _subjectToToolJson(value);
  data.remove('interest');
  data['tags'] = _formatSubjectTags(value.tags);
  data['meta_tags'] = _formatStringList(value.metaTags);
  return data;
}

Map<String, dynamic> _searchSubjectToToolJson(
  Subject value,
  Map<int, int> collectionTypeBySubjectId,
) {
  final data = _subjectToToolJson(
    value,
    collectionTypeOverride: collectionTypeBySubjectId[value.id],
  );
  data.remove('summary');
  data.remove('tags');
  data.remove('relation');
  data.remove('interest');
  data.remove('meta_tags');
  data.remove('total_episodes');
  data.remove('eps');
  data.remove('image');
  data.remove('total');
  return data;
}

Map<String, dynamic> _subjectToToolJson(
  Subject value, {
  int? collectionTypeOverride,
}) {
  final data = value.toJson();
  data['type'] = _collectionTypeLabel(
    collectionTypeOverride ?? value.interest?.type ?? 0,
  );
  return data;
}

String _formatSubjectTags(List<SubjectTag> tags) {
  return tags
      .map((tag) => '${tag.name}(${tag.count})')
      .where((item) => item.isNotEmpty)
      .join(', ');
}

String _formatStringList(List<String> items) {
  return items.where((item) => item.trim().isNotEmpty).join(', ');
}

Map<String, dynamic> _blogEntryToJson(BlogEntry value) {
  return {
    'id': value.id,
    'title': value.title,
    'content': value.content,
    'replies': value.replies,
    'createdAt': value.createdAt,
    'updatedAt': value.updatedAt,
    'user': {
      'id': value.user?.id ?? 0,
      'username': value.user?.username ?? '',
      'nickname': value.user?.nickname ?? '',
      'avatar': value.user?.avatar ?? '',
    },
  };
}

Map<String, dynamic> _blogCommentUserToJson(BlogCommentUser? value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  return {
    'id': value.id,
    'username': value.username,
    'nickname': value.nickname,
    'avatar': value.avatar,
  };
}

Map<String, dynamic> _blogCommentReplyToJson(BlogCommentReply value) {
  return {
    'id': value.id,
    'creatorId': value.creatorId,
    'createdAt': value.createdAt,
    'content': value.content,
    'state': value.state,
    'user': _blogCommentUserToJson(value.user),
  };
}

Map<String, dynamic> _blogCommentToJson(BlogComment value) {
  return {
    'id': value.id,
    'creatorId': value.creatorId,
    'createdAt': value.createdAt,
    'content': value.content,
    'state': value.state,
    'user': _blogCommentUserToJson(value.user),
    'replies': value.replies
        .map(_blogCommentReplyToJson)
        .toList(growable: false),
  };
}

String _collectionTypeLabel(int type) {
  switch (type) {
    case 1:
      return '想看';
    case 2:
      return '看过';
    case 3:
      return '在看';
    case 4:
      return '搁置';
    case 5:
      return '抛弃';
    default:
      return '未看';
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
