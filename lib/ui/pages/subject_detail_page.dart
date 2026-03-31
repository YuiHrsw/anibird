import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../backend/models/episode.dart';
import '../state/subject_detail_store.dart';
import '../widgets/subject_card.dart';

class SubjectDetailPage extends StatefulWidget {
  const SubjectDetailPage({super.key, required this.subjectId});

  final int subjectId;

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  late final SubjectDetailStore _store;
  bool _hasStartedLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedLoading) {
      return;
    }
    _store = AppScope.of(context).subjectDetailStoreFactory();
    _hasStartedLoading = true;
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
                    SubjectCard(subject: subject),
                    const SizedBox(height: 16),
                    Text('剧情简介', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(subject.summary.isEmpty ? '暂无简介。' : subject.summary),
                    const SizedBox(height: 16),
                    if (state.episodes.isNotEmpty) ...[
                      Text('剧集列表', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.episodes.take(20).map(
                        (episode) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_episodeTitle(episode)),
                          subtitle: Text(
                            episode.desc.isEmpty
                                ? _episodeMeta(episode)
                                : '${_episodeMeta(episode)}\n${episode.desc}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showEpisodeDetail(episode),
                        ),
                      ),
                      if (state.episodes.length > 20)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('已显示前 20 集，共 ${state.episodes.length} 集。'),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (state.characters.isNotEmpty) ...[
                      Text('角色阵容', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.characters.take(6).map(
                        (character) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(character.name),
                          subtitle: Text(
                            '${character.relation}${character.actors.isEmpty ? '' : ' · ${character.actors.join(' / ')}'}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.persons.isNotEmpty) ...[
                      Text('制作人员', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.persons.take(6).map(
                        (person) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(person.name),
                          subtitle: Text(
                            '${person.relation}${person.careers.isEmpty ? '' : ' · ${person.careers.join(' / ')}'}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.relatedSubjects.isNotEmpty) ...[
                      Text('关联作品', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...state.relatedSubjects.take(5).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SubjectCard(
                            subject: item,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SubjectDetailPage(subjectId: item.id),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<void> _showEpisodeDetail(Episode episode) async {
    final detail = await _store.loadEpisodeDetail(episode.id) ?? episode;
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final resolved = _store.value.episodeDetails[episode.id] ?? detail;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _episodeTitle(resolved),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _episodeMeta(resolved),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    resolved.desc.isEmpty ? '暂无单集简介。' : resolved.desc,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _episodeTitle(Episode episode) {
    final prefix = episode.ep == null ? 'SP' : '第${episode.ep!.toStringAsFixed(episode.ep! % 1 == 0 ? 0 : 1)}话';
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
}
