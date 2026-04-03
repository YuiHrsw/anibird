import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../state/timeline_store.dart';
import 'timeline_widgets.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final TimelineStore _store;
  bool _hasBoundStore = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasBoundStore) {
      _store = AppScope.of(context).timelineStore;
      _hasBoundStore = true;
      _store.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TimelineState>(
      valueListenable: _store,
      builder: (context, state, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '时间线',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: state.isLoading || state.isRefreshing ? null : _store.refresh,
                  icon: state.isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '只读浏览 Bangumi 时间线动态。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TimelineModeChip(
                  label: '关注',
                  mode: TimelineMode.friends,
                  selectedMode: state.mode,
                  onSelected: () => _store.load(TimelineMode.friends),
                ),
                TimelineModeChip(
                  label: '全站',
                  mode: TimelineMode.all,
                  selectedMode: state.mode,
                  onSelected: () => _store.load(TimelineMode.all),
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
                  '这里还没有可显示的时间线动态。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              ...state.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TimelineCard(item: item),
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              if (state.hasMore)
                FilledButton.tonal(
                  onPressed: state.isLoadingMore ? null : _store.loadMore,
                  child: Text(state.isLoadingMore ? '加载中...' : '加载更多'),
                ),
            ],
          ],
        );
      },
    );
  }
}
