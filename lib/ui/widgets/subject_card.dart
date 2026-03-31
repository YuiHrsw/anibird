import 'package:flutter/material.dart';

import '../../backend/models/subject.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({super.key, required this.subject, this.onTap});

  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              height: 132,
              child: subject.image.isEmpty
                  ? const _ImageFallback()
                  : Image.network(
                      subject.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const _ImageLoading();
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const _ImageFallback();
                      },
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subject.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                    const SizedBox(height: 8),
                    Text(
                      subject.summary.isEmpty ? '暂无简介。' : subject.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF1E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD8E8E1),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD8E8E1),
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
      ),
    );
  }
}
