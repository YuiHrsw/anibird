class AgentToolConfigEntry {
  const AgentToolConfigEntry({
    required this.name,
    required this.title,
    required this.description,
    this.defaultEnabled = true,
  });

  final String name;
  final String title;
  final String description;
  final bool defaultEnabled;
}

const List<AgentToolConfigEntry> availableAgentToolConfigs = [
  AgentToolConfigEntry(
    name: 'search_anime',
    title: '搜索动画',
    description: '根据关键词、题材和标签搜索动画条目。',
  ),
  AgentToolConfigEntry(
    name: 'search_subjects_by_tags',
    title: '按标签搜索',
    description: '根据 tag 和 meta tag 搜索更相关的动画候选。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_detail',
    title: '条目详情',
    description: '获取 Bangumi 条目详情。',
  ),
  AgentToolConfigEntry(
    name: 'get_related_subjects',
    title: '关联作品',
    description: '获取续作、前传和其他关联条目。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_cast',
    title: '角色与制作',
    description: '获取角色和制作人员阵容。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_episodes',
    title: '单集列表',
    description: '获取条目的单集列表和集数结构。',
  ),
  AgentToolConfigEntry(
    name: 'get_episode_detail',
    title: '单集详情',
    description: '获取单集简介、播出时间和时长等信息。',
  ),
  AgentToolConfigEntry(
    name: 'browse_subjects',
    title: '浏览榜单',
    description: '浏览动画榜单和热门条目。',
  ),
  AgentToolConfigEntry(
    name: 'get_my_profile',
    title: '当前用户',
    description: '读取当前登录 Bangumi 账号信息。',
  ),
  AgentToolConfigEntry(
    name: 'get_my_collections',
    title: '我的收藏',
    description: '读取当前账号的动画收藏列表。',
  ),
  AgentToolConfigEntry(
    name: 'get_episode_comments',
    title: '单集评论',
    description: '读取单集评论和回复。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_comments',
    title: '条目吐槽',
    description: '读取条目的评论吐槽。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_topics',
    title: '条目讨论版',
    description: '读取条目讨论主题。',
  ),
  AgentToolConfigEntry(
    name: 'get_subject_reviews',
    title: '条目长评',
    description: '读取条目长评摘要。',
  ),
  AgentToolConfigEntry(
    name: 'get_timeline',
    title: '时间线',
    description: '读取 Bangumi 时间线动态。',
  ),
  AgentToolConfigEntry(
    name: 'get_blog_entry',
    title: '日志详情',
    description: '读取日志正文。',
  ),
  AgentToolConfigEntry(
    name: 'get_blog_comments',
    title: '日志评论',
    description: '读取日志评论和回复。',
  ),
  // AgentToolConfigEntry(
  //   name: 'mark_final_answer_start',
  //   title: '标记最终答案开始',
  //   description: '标记从这里开始进入最终给用户展示的答案区。也可用于重置回答区域',
  // ),
  // AgentToolConfigEntry(
  //   name: 'set_recommendations',
  //   title: '设置推荐',
  //   description: '设置最终回答下方展示的推荐条目卡片。',
  // ),
];

const List<String> defaultEnabledAgentToolNames = [
  'search_anime',
  'search_subjects_by_tags',
  'get_subject_detail',
  'get_related_subjects',
  'get_subject_cast',
  'get_subject_episodes',
  'get_episode_detail',
  'browse_subjects',
  'get_my_profile',
  'get_my_collections',
  'get_episode_comments',
  'get_subject_comments',
  'get_subject_topics',
  'get_subject_reviews',
  'get_timeline',
  'get_blog_entry',
  'get_blog_comments',
  'mark_final_answer_start',
  'set_recommendations',
];
