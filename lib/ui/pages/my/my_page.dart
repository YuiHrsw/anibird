import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../state/my_collections_store.dart';
import '../../widgets/subject_card.dart';
import 'my_widgets.dart';
import '../subject_detail_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late final MyCollectionsStore _store;
  bool _hasBoundStore = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasBoundStore) {
      _store = AppScope.of(context).myCollectionsStore;
      _hasBoundStore = true;
      _refreshOnOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MyCollectionsState>(
      valueListenable: _store,
      builder: (context, state, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('我的动画', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '查看当前登录 Bangumi 账号的动画收藏。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
                children: const [
                CollectionFilterChip(
                  label: '在看',
                  type: SubjectCollectionType.doing,
                ),
                CollectionFilterChip(
                  label: '看过',
                  type: SubjectCollectionType.collect,
                ),
                CollectionFilterChip(
                  label: '想看',
                  type: SubjectCollectionType.wish,
                ),
                CollectionFilterChip(
                  label: '搁置',
                  type: SubjectCollectionType.onHold,
                ),
                CollectionFilterChip(
                  label: '抛弃',
                  type: SubjectCollectionType.dropped,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  state.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              )
            else if (state.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${labelForCollectionType(state.selectedType)}里还没有动画。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...state.items.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    children: [
                      SubjectCard(
                        subject: subject,
                        footer: SubjectInterestSummary(subject: subject),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SubjectDetailPage(subjectId: subject.id),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _refreshOnOpen() async {
    await _store.refreshOnOpen();
  }
}
