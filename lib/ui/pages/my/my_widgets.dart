import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../backend/models/subject.dart';
import '../../state/my_collections_store.dart';

class CollectionFilterChip extends StatelessWidget {
  const CollectionFilterChip({
    super.key,
    required this.label,
    required this.type,
  });

  final String label;
  final int type;

  @override
  Widget build(BuildContext context) {
    final store = context.myCollectionsStore;
    return ValueListenableBuilder<MyCollectionsState>(
      valueListenable: store,
      builder: (context, state, _) {
        return ChoiceChip(
          label: Text(label),
          selected: state.selectedType == type,
          onSelected: state.isLoading
              ? null
              : (selected) {
                  if (selected) {
                    store.selectType(type);
                  }
                },
        );
      },
    );
  }
}

class SubjectInterestSummary extends StatelessWidget {
  const SubjectInterestSummary({super.key, required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final interest = subject.interest;
    if (interest == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final parts = <String>[
      labelForCollectionType(interest.type),
      if (interest.rate > 0) '评分 ${interest.rate}',
      if (interest.tags.isNotEmpty) interest.tags.take(3).join(' / '),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        parts.join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String labelForCollectionType(int type) {
  switch (type) {
    case SubjectCollectionType.wish:
      return '想看';
    case SubjectCollectionType.collect:
      return '看过';
    case SubjectCollectionType.doing:
      return '在看';
    case SubjectCollectionType.onHold:
      return '搁置';
    case SubjectCollectionType.dropped:
      return '抛弃';
    default:
      return '未分类';
  }
}
