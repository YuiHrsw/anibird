import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../backend/api/bangumi/bangumi_private_repository.dart';
import '../../backend/api/my_collections_cache_repository.dart';
import '../../backend/models/subject.dart';

class SubjectCollectionType {
  static const int wish = 1;
  static const int collect = 2;
  static const int doing = 3;
  static const int onHold = 4;
  static const int dropped = 5;
}

enum MyCollectionsRefreshResult { refreshed, noNewData, failed }

@immutable
class MyCollectionsState {
  const MyCollectionsState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedType = SubjectCollectionType.doing,
    this.items = const <Subject>[],
  });

  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final int selectedType;
  final List<Subject> items;

  MyCollectionsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    int? selectedType,
    List<Subject>? items,
  }) {
    return MyCollectionsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : error ?? this.error,
      selectedType: selectedType ?? this.selectedType,
      items: items ?? this.items,
    );
  }
}

class MyCollectionsStore extends ValueNotifier<MyCollectionsState> {
  MyCollectionsStore(this._repository, this._cacheRepository)
    : super(const MyCollectionsState());

  static const List<int> _trackedTypes = <int>[
    SubjectCollectionType.doing,
    SubjectCollectionType.collect,
    SubjectCollectionType.wish,
    SubjectCollectionType.onHold,
    SubjectCollectionType.dropped,
  ];

  final BangumiPrivateRepository _repository;
  final MyCollectionsCacheRepository? _cacheRepository;
  Map<int, List<Subject>> _itemsByType = <int, List<Subject>>{};
  bool _cacheLoaded = false;
  bool _refreshing = false;

  Future<MyCollectionsRefreshResult> refreshOnOpen() async {
    await _ensureCacheLoaded();
    final hasAnyCache = _hasAnyItems(_itemsByType);
    value = value.copyWith(
      isLoading: !hasAnyCache,
      isRefreshing: hasAnyCache,
      items: _itemsForType(value.selectedType),
      clearError: true,
    );
    return _refreshAll();
  }

  Future<MyCollectionsRefreshResult> refresh() async {
    await _ensureCacheLoaded();
    final hasAnyCache = _hasAnyItems(_itemsByType);
    value = value.copyWith(
      isLoading: !hasAnyCache,
      isRefreshing: hasAnyCache,
      items: _itemsForType(value.selectedType),
      clearError: true,
    );
    return _refreshAll();
  }

  void selectType(int type) {
    if (value.selectedType == type) {
      return;
    }
    value = value.copyWith(
      selectedType: type,
      items: _itemsForType(type),
      clearError: true,
    );
  }

  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) {
      return;
    }
    _itemsByType = Map<int, List<Subject>>.from(
      await _cacheRepository?.loadAll() ?? const <int, List<Subject>>{},
    );
    _cacheLoaded = true;
  }

  List<Subject> _itemsForType(int type) {
    return _itemsByType[type] ?? const <Subject>[];
  }

  bool _hasAnyItems(Map<int, List<Subject>> itemsByType) {
    for (final type in _trackedTypes) {
      if ((itemsByType[type] ?? const <Subject>[]).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<MyCollectionsRefreshResult> _refreshAll() async {
    if (_refreshing) {
      return MyCollectionsRefreshResult.noNewData;
    }
    _refreshing = true;
    var hasChanges = false;
    Object? firstError;
    try {
      for (final type in _trackedTypes) {
        try {
          final nextItems = await _fetchAllForType(type);
          final cachedItems = _itemsForType(type);
          if (!_sameSubjects(cachedItems, nextItems)) {
            _itemsByType[type] = List<Subject>.unmodifiable(nextItems);
            await _cacheRepository?.save(type, nextItems);
            hasChanges = true;
          }
        } catch (error) {
          firstError ??= error;
        }
      }
      value = value.copyWith(
        isLoading: false,
        isRefreshing: false,
        items: _itemsForType(value.selectedType),
        error: firstError?.toString(),
        clearError: firstError == null,
      );
      if (hasChanges) {
        return MyCollectionsRefreshResult.refreshed;
      }
      return firstError == null
          ? MyCollectionsRefreshResult.noNewData
          : MyCollectionsRefreshResult.failed;
    } finally {
      _refreshing = false;
    }
  }

  Future<List<Subject>> _fetchAllForType(int type) async {
    const pageSize = 50;
    var offset = 0;
    var total = 0;
    final items = <Subject>[];
    do {
      final result = await _repository.getMySubjectCollections(
        type: type,
        limit: pageSize,
        offset: offset,
      );
      total = result.total;
      items.addAll(result.data);
      offset += result.data.length;
      if (result.data.isEmpty) {
        break;
      }
    } while (offset < total);
    return List<Subject>.unmodifiable(items);
  }

  Future<void> clearMemoryCache() async {
    _itemsByType = <int, List<Subject>>{};
    _cacheLoaded = false;
    value = value.copyWith(
      isLoading: false,
      isRefreshing: false,
      items: const <Subject>[],
      clearError: true,
    );
  }

  bool _sameSubjects(List<Subject> a, List<Subject> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    return jsonEncode(a.map((item) => item.toJson()).toList(growable: false)) ==
        jsonEncode(b.map((item) => item.toJson()).toList(growable: false));
  }
}
