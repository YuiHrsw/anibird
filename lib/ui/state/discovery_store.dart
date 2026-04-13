import 'package:flutter/foundation.dart';

import '../../backend/api/bangumi/bangumi_repository.dart';
import '../../backend/models/browse_query.dart';
import '../../backend/models/search_query.dart';
import '../../backend/models/subject.dart';

@immutable
class DiscoveryState {
  const DiscoveryState({
    this.isLoading = false,
    this.hasLoadedFeatured = false,
    this.error,
    this.featured = const <Subject>[],
    this.searchResults = const <Subject>[],
    this.keyword = '',
  });

  final bool isLoading;
  final bool hasLoadedFeatured;
  final String? error;
  final List<Subject> featured;
  final List<Subject> searchResults;
  final String keyword;

  DiscoveryState copyWith({
    bool? isLoading,
    bool? hasLoadedFeatured,
    String? error,
    bool clearError = false,
    List<Subject>? featured,
    List<Subject>? searchResults,
    String? keyword,
  }) {
    return DiscoveryState(
      isLoading: isLoading ?? this.isLoading,
      hasLoadedFeatured: hasLoadedFeatured ?? this.hasLoadedFeatured,
      error: clearError ? null : error ?? this.error,
      featured: featured ?? this.featured,
      searchResults: searchResults ?? this.searchResults,
      keyword: keyword ?? this.keyword,
    );
  }
}

class DiscoveryStore extends ValueNotifier<DiscoveryState> {
  DiscoveryStore(this._repository) : super(const DiscoveryState());

  final BangumiRepository _repository;

  Future<void> loadFeatured() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.browseSubjects(const BrowseQuery());
      value = value.copyWith(
        isLoading: false,
        hasLoadedFeatured: true,
        featured: page.data,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        hasLoadedFeatured: true,
        error: error.toString(),
      );
    }
  }

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      value = value.copyWith(
        keyword: '',
        searchResults: const <Subject>[],
        clearError: true,
      );
      return;
    }

    value = value.copyWith(isLoading: true, keyword: trimmed, clearError: true);
    try {
      final page = await _repository.searchSubjects(
        SearchQuery(keyword: trimmed, limit: 12),
      );
      value = value.copyWith(isLoading: false, searchResults: page.data);
    } catch (error) {
      value = value.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> refresh() async {
    if (value.keyword.trim().isEmpty) {
      await loadFeatured();
      return;
    }
    await search(value.keyword);
  }
}
