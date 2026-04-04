import 'package:flutter/foundation.dart';

import '../../backend/api/bangumi/bangumi_private_repository.dart';
import '../../backend/models/timeline_item.dart';

class TimelineMode {
  static const String friends = 'friends';
  static const String all = 'all';
}

@immutable
class TimelineState {
  const TimelineState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.mode = TimelineMode.friends,
    this.items = const <TimelineItem>[],
    this.hasMore = true,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final String mode;
  final List<TimelineItem> items;
  final bool hasMore;

  TimelineState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? mode,
    List<TimelineItem>? items,
    bool? hasMore,
  }) {
    return TimelineState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      mode: mode ?? this.mode,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TimelineStore extends ValueNotifier<TimelineState> {
  TimelineStore(this._repository) : super(const TimelineState());

  final BangumiPrivateRepository _repository;

  Future<void> load([String? nextMode]) async {
    final mode = nextMode ?? value.mode;
    value = value.copyWith(
      isLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      mode: mode,
      items: const <TimelineItem>[],
      hasMore: true,
      clearError: true,
    );
    try {
      final items = await _repository.getTimeline(mode: mode);
      value = value.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length >= 20,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        error: error.toString(),
        items: const <TimelineItem>[],
        hasMore: false,
      );
    }
  }

  Future<void> refresh() async {
    value = value.copyWith(isRefreshing: true, clearError: true);
    try {
      final items = await _repository.getTimeline(mode: value.mode);
      value = value.copyWith(
        isRefreshing: false,
        items: items,
        hasMore: items.length >= 20,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isRefreshing: false,
        error: error.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (value.isLoading || value.isLoadingMore || !value.hasMore || value.items.isEmpty) {
      return;
    }
    value = value.copyWith(isLoadingMore: true, clearError: true);
    try {
      final items = await _repository.getTimeline(
        mode: value.mode,
        until: value.items.last.id,
      );
      final merged = <TimelineItem>[
        ...value.items,
        ...items.where((item) => value.items.every((existing) => existing.id != item.id)),
      ];
      value = value.copyWith(
        isLoadingMore: false,
        items: merged,
        hasMore: items.length >= 20,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }
}
