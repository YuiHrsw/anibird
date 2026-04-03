import 'package:flutter/material.dart';

import '../../backend/models/subject.dart';
import 'app_network_image.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({
    super.key,
    required this.subject,
    this.onTap,
    this.footer,
  });

  final Subject subject;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subject.nameCn.isNotEmpty &&
                          subject.nameCn != subject.name)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subject.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoPill(
                            label: '评分 ${subject.score.toStringAsFixed(1)}',
                          ),
                          _InfoPill(
                            label:
                                'Rank ${subject.rank == 0 ? '-' : subject.rank}',
                          ),
                          if (subject.date.isNotEmpty)
                            _InfoPill(label: subject.date),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subject.summary.isEmpty ? '暂无简介。' : subject.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ...?footer == null ? null : <Widget>[footer!],
                    ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

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
