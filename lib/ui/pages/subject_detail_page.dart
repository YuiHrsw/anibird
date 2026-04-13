import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../backend/models/episode.dart';
import '../../backend/models/episode_comment.dart';
import '../../backend/models/blog_comment.dart';
import '../../backend/models/blog_entry.dart';
import '../../backend/models/subject.dart';
import '../../backend/models/subject_discussion.dart';
import '../../backend/models/subject_review.dart';
import '../state/subject_detail_store.dart';
import '../widgets/app_network_image.dart';

class SubjectDetailPage extends StatefulWidget {
  const SubjectDetailPage({super.key, required this.subjectId});

  final int subjectId;

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  late final SubjectDetailStore _store;

  @override
  void initState() {
    super.initState();
    _store = context.readAppDependencies.subjectDetailStoreFactory();
    _store.load(widget.subjectId);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubjectDetailState>(
      valueListenable: _store,
      builder: (context, state, _) {
        final subject = state.subject;
        return Scaffold(
          appBar: AppBar(title: Text(subject?.displayName ?? '条目详情')),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(state.error!),
                  ),
                )
              : subject == null
              ? const Center(child: Text('未找到条目。'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SubjectHeader(subject: subject),
                    const SizedBox(height: 16),
                    Text('剧情简介', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(subject.summary.isEmpty ? '暂无简介。' : subject.summary),
                    const SizedBox(height: 16),
                    if (state.episodes.isNotEmpty) ...[
                      Text(
                        '剧集列表 · 共 ${state.episodes.length} 集',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: state.episodes
                            .map(
                              (episode) => _EpisodeGridTile(
                                episode: episode,
                                onTap: () => _openEpisodeDetailPage(episode),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.characters.isNotEmpty) ...[
                      Text('角色阵容', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 188,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.characters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final character = state.characters[index];
                            return _PosterTile(
                              imageUrl: character.image,
                              title: character.name,
                              subtitle: character.relation,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.persons.isNotEmpty) ...[
                      Text('制作人员', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 188,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.persons.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final person = state.persons[index];
                            return _PosterTile(
                              imageUrl: person.image,
                              title: person.name,
                              subtitle: person.relation,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.subjectComments.isNotEmpty) ...[
                      Text('全剧吐槽', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.subjectComments.take(6).map(
                        (comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubjectCommentCard(comment: comment),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.subjectTopics.isNotEmpty) ...[
                      Text('全剧讨论', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.subjectTopics.take(6).map(
                        (topic) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubjectTopicCard(topic: topic),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.subjectReviews.isNotEmpty) ...[
                      Text('全剧评论', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.subjectReviews.take(6).map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubjectReviewCard(
                            review: review,
                            onTap: () => _openReviewDetailPage(review),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.relatedSubjects.isNotEmpty) ...[
                      Text('关联作品', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 188,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.relatedSubjects.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = state.relatedSubjects[index];
                            return _PosterTile(
                              imageUrl: item.image,
                              title: item.displayName,
                              subtitle: item.relation ?? '',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SubjectDetailPage(subjectId: item.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openEpisodeDetailPage(Episode episode) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EpisodeDetailPage(
          store: _store,
          initialEpisode: episode,
        ),
      ),
    );
  }

  Future<void> _openReviewDetailPage(SubjectReview review) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SubjectReviewDetailPage(
          review: review,
          store: _store,
        ),
      ),
    );
  }

}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 88,
            height: 126,
            child: AppNetworkImage(imageUrl: subject.image),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.displayName,
                  style: textTheme.titleMedium,
                ),
                if (subject.nameCn.isNotEmpty && subject.nameCn != subject.name)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subject.name,
                      style: textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (subject.interest != null)
                      _SubjectHeaderPill(
                        label: _subjectCollectionTypeLabel(subject.interest!.type),
                      ),
                    _SubjectHeaderPill(
                      label: '${subject.score.toStringAsFixed(1)} / 10',
                    ),
                    _SubjectHeaderPill(
                      label: 'Rank ${subject.rank == 0 ? '-' : subject.rank}',
                    ),
                    if (subject.date.isNotEmpty)
                      _SubjectHeaderPill(label: subject.date),
                  ],
                ),
                _SubjectTagsSummary(subject: subject),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectHeaderPill extends StatelessWidget {
  const _SubjectHeaderPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _EpisodeGridTile extends StatelessWidget {
  const _EpisodeGridTile({
    required this.episode,
    required this.onTap,
  });

  final Episode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = episode.collection?.isDone ?? false;
    final label = episode.ep == null
        ? (episode.sort % 1 == 0
              ? episode.sort.toStringAsFixed(0)
              : episode.sort.toStringAsFixed(1))
        : episode.ep!.toStringAsFixed(episode.ep! % 1 == 0 ? 0 : 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDone
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isDone
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDone
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _episodeTitle(Episode episode) {
  final prefix = episode.ep == null
      ? 'SP'
      : '第${episode.ep!.toStringAsFixed(episode.ep! % 1 == 0 ? 0 : 1)}话';
  return '$prefix ${episode.displayName}';
}

String _episodeMeta(Episode episode) {
  final parts = <String>[
    if (episode.airdate.isNotEmpty) episode.airdate,
    if (episode.duration.isNotEmpty) episode.duration,
    '评论 ${episode.comment}',
  ];
  return parts.join(' · ');
}

class _EpisodeDetailPage extends StatefulWidget {
  const _EpisodeDetailPage({
    required this.store,
    required this.initialEpisode,
  });

  final SubjectDetailStore store;
  final Episode initialEpisode;

  @override
  State<_EpisodeDetailPage> createState() => _EpisodeDetailPageState();
}

class _EpisodeDetailPageState extends State<_EpisodeDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.loadEpisodeDetail(widget.initialEpisode.id);
      await widget.store.loadEpisodeComments(widget.initialEpisode.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubjectDetailState>(
      valueListenable: widget.store,
      builder: (context, state, _) {
        final episode =
            state.episodeDetails[widget.initialEpisode.id] ?? widget.initialEpisode;
        final comments =
            state.episodeComments[widget.initialEpisode.id] ??
            const <EpisodeComment>[];
        final isLoadingComments = state.loadingEpisodeCommentIds.contains(
          widget.initialEpisode.id,
        );
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: Text(_episodeTitle(episode))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _episodeTitle(episode),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _episodeMeta(episode),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                episode.desc.isEmpty ? '暂无单集简介。' : episode.desc,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                '吐槽 / 讨论',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (isLoadingComments)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '这集还没有吐槽。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ...comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _EpisodeCommentCard(comment: comment),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeCommentCard extends StatelessWidget {
  const _EpisodeCommentCard({required this.comment});

  final EpisodeComment comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = comment.user;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user?.displayName ?? '匿名用户',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            comment.content.isEmpty ? '（无内容）' : comment.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply.user?.displayName ?? '匿名回复',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply.content.isEmpty ? '（无内容）' : reply.content,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 102,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 102,
                height: 120,
                child: ColoredBox(
                  color: Colors.white,
                  child: imageUrl.isEmpty
                      ? const AppNetworkImage(imageUrl: '')
                      : AppNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTagsSummary extends StatelessWidget {
  const _SubjectTagsSummary({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      ...subject.metaTags.where((tag) => tag.trim().isNotEmpty),
      ...subject.tags
          .map((tag) => tag.name)
          .where((tag) => tag.trim().isNotEmpty),
    ];
    final uniqueTags = <String>[];
    for (final tag in tags) {
      if (!uniqueTags.contains(tag)) {
        uniqueTags.add(tag);
      }
    }
    if (uniqueTags.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: uniqueTags.take(10).map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SubjectCommentCard extends StatelessWidget {
  const _SubjectCommentCard({required this.comment});

  final SubjectComment comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.user?.displayName ?? '匿名用户',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                _subjectCollectionTypeLabel(comment.type),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          if (comment.rate > 0) ...[
            const SizedBox(height: 4),
            Text(
              '评分 ${comment.rate}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            comment.comment.isEmpty ? '（无内容）' : comment.comment,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SubjectReviewCard extends StatelessWidget {
  const _SubjectReviewCard({
    required this.review,
    this.onTap,
  });

  final SubjectReview review;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.entry.title.isEmpty ? '（无标题）' : review.entry.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '${review.user?.displayName ?? '匿名用户'} · 回复 ${review.entry.replies}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (review.entry.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  review.entry.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectReviewDetailPage extends StatefulWidget {
  const _SubjectReviewDetailPage({
    required this.review,
    required this.store,
  });

  final SubjectReview review;
  final SubjectDetailStore store;

  @override
  State<_SubjectReviewDetailPage> createState() => _SubjectReviewDetailPageState();
}

class _SubjectReviewDetailPageState extends State<_SubjectReviewDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.loadReviewEntry(widget.review.entry.id);
      await widget.store.loadReviewComments(widget.review.entry.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubjectDetailState>(
      valueListenable: widget.store,
      builder: (context, state, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final fullEntry = state.reviewEntries[widget.review.entry.id];
        final comments =
            state.reviewComments[widget.review.entry.id] ?? const <BlogComment>[];
        final isLoadingEntry = state.loadingReviewEntryIds.contains(
          widget.review.entry.id,
        );
        final isLoadingComments = state.loadingReviewCommentIds.contains(
          widget.review.entry.id,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              fullEntry?.title.isNotEmpty == true
                  ? fullEntry!.title
                  : (widget.review.entry.title.isEmpty ? '全剧评论' : widget.review.entry.title),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                fullEntry?.title.isNotEmpty == true
                    ? fullEntry!.title
                    : (widget.review.entry.title.isEmpty ? '（无标题）' : widget.review.entry.title),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${fullEntry?.user?.displayName ?? widget.review.user?.displayName ?? '匿名用户'} · 回复 ${fullEntry?.replies ?? widget.review.entry.replies}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (isLoadingEntry && fullEntry == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SelectableText(
                  _reviewContent(fullEntry, widget.review),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 24),
              Text(
                '回复',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (isLoadingComments && comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (comments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '这条评论还没有回复。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ...comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BlogCommentCard(comment: comment),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _reviewContent(BlogEntry? fullEntry, SubjectReview review) {
  if (fullEntry != null && fullEntry.content.isNotEmpty) {
    return fullEntry.content;
  }
  if (review.entry.summary.isNotEmpty) {
    return review.entry.summary;
  }
  return '暂无评论内容。';
}

class _BlogCommentCard extends StatelessWidget {
  const _BlogCommentCard({required this.comment});

  final BlogComment comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.user?.displayName ?? '匿名用户',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            comment.content.isEmpty ? '（无内容）' : comment.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply.user?.displayName ?? '匿名回复',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply.content.isEmpty ? '（无内容）' : reply.content,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectTopicCard extends StatelessWidget {
  const _SubjectTopicCard({required this.topic});

  final SubjectTopic topic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title.isEmpty ? '（无标题）' : topic.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${topic.creator?.displayName ?? '匿名用户'} · 回复 ${topic.replyCount}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _subjectCollectionTypeLabel(int type) {
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
      return '收藏';
  }
}
