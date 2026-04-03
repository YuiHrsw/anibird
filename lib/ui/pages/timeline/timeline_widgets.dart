import 'package:flutter/material.dart';

import '../../../backend/models/timeline_item.dart';
import '../../widgets/app_network_image.dart';
import '../subject_detail_page.dart';

class TimelineModeChip extends StatelessWidget {
  const TimelineModeChip({
    super.key,
    required this.label,
    required this.mode,
    required this.selectedMode,
    required this.onSelected,
  });

  final String label;
  final String mode;
  final String selectedMode;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedMode == mode,
      onSelected: (selected) {
        if (selected && selectedMode != mode) {
          onSelected();
        }
      },
    );
  }
}

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: AppNetworkImage(
                    imageUrl: item.user?.avatar ?? '',
                    icon: Icons.person_outline,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.user?.displayName ?? 'Bangumi 用户',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatTimelineTime(item.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (item.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.detail,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (item.subjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.subjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final subject = item.subjects[index];
                  return TimelineSubjectTile(subject: subject);
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.sourceName.isNotEmpty)
                Text(
                  item.sourceName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (item.sourceName.isNotEmpty && item.replies > 0)
                Text(
                  ' · ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (item.replies > 0)
                Text(
                  '${item.replies} 条回复',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant,
          ),
        ],
      ),
    );
  }
}

class TimelineSubjectTile extends StatelessWidget {
  const TimelineSubjectTile({super.key, required this.subject});

  final TimelineSubjectRef subject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SubjectDetailPage(subjectId: subject.id),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: SizedBox(
                  width: 56,
                  height: 88,
                  child: AppNetworkImage(imageUrl: subject.image),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    subject.displayName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatTimelineTime(int createdAt) {
  if (createdAt <= 0) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
