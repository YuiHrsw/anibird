import 'package:flutter/foundation.dart';

import '../../backend/api/bangumi/bangumi_private_repository.dart';
import '../../backend/api/bangumi/bangumi_repository.dart';
import '../../backend/models/episode.dart';
import '../../backend/models/episode_comment.dart';
import '../../backend/models/blog_comment.dart';
import '../../backend/models/blog_entry.dart';
import '../../backend/models/related_character.dart';
import '../../backend/models/related_person.dart';
import '../../backend/models/subject.dart';
import '../../backend/models/subject_discussion.dart';
import '../../backend/models/subject_review.dart';

@immutable
class SubjectDetailState {
  const SubjectDetailState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
    this.subject,
    this.relatedSubjects = const <Subject>[],
    this.episodes = const <Episode>[],
    this.episodeDetails = const <int, Episode>{},
    this.episodeComments = const <int, List<EpisodeComment>>{},
    this.loadingEpisodeIds = const <int>[],
    this.loadingEpisodeCommentIds = const <int>[],
    this.reviewEntries = const <int, BlogEntry>{},
    this.reviewComments = const <int, List<BlogComment>>{},
    this.loadingReviewEntryIds = const <int>[],
    this.loadingReviewCommentIds = const <int>[],
    this.subjectComments = const <SubjectComment>[],
    this.subjectTopics = const <SubjectTopic>[],
    this.subjectReviews = const <SubjectReview>[],
    this.characters = const <RelatedCharacter>[],
    this.persons = const <RelatedPerson>[],
  });

  final bool isLoading;
  final bool hasLoaded;
  final String? error;
  final Subject? subject;
  final List<Subject> relatedSubjects;
  final List<Episode> episodes;
  final Map<int, Episode> episodeDetails;
  final Map<int, List<EpisodeComment>> episodeComments;
  final List<int> loadingEpisodeIds;
  final List<int> loadingEpisodeCommentIds;
  final Map<int, BlogEntry> reviewEntries;
  final Map<int, List<BlogComment>> reviewComments;
  final List<int> loadingReviewEntryIds;
  final List<int> loadingReviewCommentIds;
  final List<SubjectComment> subjectComments;
  final List<SubjectTopic> subjectTopics;
  final List<SubjectReview> subjectReviews;
  final List<RelatedCharacter> characters;
  final List<RelatedPerson> persons;

  SubjectDetailState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    String? error,
    bool clearError = false,
    Subject? subject,
    List<Subject>? relatedSubjects,
    List<Episode>? episodes,
    Map<int, Episode>? episodeDetails,
    Map<int, List<EpisodeComment>>? episodeComments,
    List<int>? loadingEpisodeIds,
    List<int>? loadingEpisodeCommentIds,
    Map<int, BlogEntry>? reviewEntries,
    Map<int, List<BlogComment>>? reviewComments,
    List<int>? loadingReviewEntryIds,
    List<int>? loadingReviewCommentIds,
    List<SubjectComment>? subjectComments,
    List<SubjectTopic>? subjectTopics,
    List<SubjectReview>? subjectReviews,
    List<RelatedCharacter>? characters,
    List<RelatedPerson>? persons,
  }) {
    return SubjectDetailState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: clearError ? null : error ?? this.error,
      subject: subject ?? this.subject,
      relatedSubjects: relatedSubjects ?? this.relatedSubjects,
      episodes: episodes ?? this.episodes,
      episodeDetails: episodeDetails ?? this.episodeDetails,
      episodeComments: episodeComments ?? this.episodeComments,
      loadingEpisodeIds: loadingEpisodeIds ?? this.loadingEpisodeIds,
      loadingEpisodeCommentIds:
          loadingEpisodeCommentIds ?? this.loadingEpisodeCommentIds,
      reviewEntries: reviewEntries ?? this.reviewEntries,
      reviewComments: reviewComments ?? this.reviewComments,
      loadingReviewEntryIds:
          loadingReviewEntryIds ?? this.loadingReviewEntryIds,
      loadingReviewCommentIds:
          loadingReviewCommentIds ?? this.loadingReviewCommentIds,
      subjectComments: subjectComments ?? this.subjectComments,
      subjectTopics: subjectTopics ?? this.subjectTopics,
      subjectReviews: subjectReviews ?? this.subjectReviews,
      characters: characters ?? this.characters,
      persons: persons ?? this.persons,
    );
  }
}

class SubjectDetailStore extends ValueNotifier<SubjectDetailState> {
  SubjectDetailStore(this._repository, this._privateRepository)
    : super(const SubjectDetailState());

  final BangumiRepository _repository;
  final BangumiPrivateRepository _privateRepository;
  bool _isDisposed = false;

  Future<void> load(int subjectId) async {
    _setValue(value.copyWith(isLoading: true, clearError: true));
    try {
      final subject = await _repository.getSubjectDetail(subjectId);
      final relatedSubjects = await _repository.getRelatedSubjects(subjectId);
      final episodes = await _privateRepository.getSubjectEpisodes(subjectId);
      final subjectComments = await _privateRepository.getSubjectComments(
        subjectId,
      );
      final subjectTopics = await _privateRepository.getSubjectTopics(subjectId);
      final subjectReviews = await _privateRepository.getSubjectReviews(subjectId);
      final characters = await _repository.getRelatedCharacters(subjectId);
      final persons = await _repository.getRelatedPersons(subjectId);
      _setValue(value.copyWith(
        isLoading: false,
        hasLoaded: true,
        subject: subject,
        relatedSubjects: relatedSubjects,
        episodes: episodes.data,
        subjectComments: subjectComments.data,
        subjectTopics: subjectTopics.data,
        subjectReviews: subjectReviews.data,
        characters: characters,
        persons: persons,
      ));
    } catch (error) {
      _setValue(value.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: error.toString(),
      ));
    }
  }

  Future<Episode?> loadEpisodeDetail(int episodeId) async {
    if (value.episodeDetails.containsKey(episodeId)) {
      return value.episodeDetails[episodeId];
    }
    if (value.loadingEpisodeIds.contains(episodeId)) {
      return null;
    }

    _setValue(value.copyWith(
      loadingEpisodeIds: <int>[...value.loadingEpisodeIds, episodeId],
    ));
    try {
      final episode = await _privateRepository.getEpisodeDetail(episodeId);
      final details = <int, Episode>{...value.episodeDetails, episodeId: episode};
      _setValue(value.copyWith(
        episodeDetails: details,
        loadingEpisodeIds: value.loadingEpisodeIds
            .where((item) => item != episodeId)
            .toList(growable: false),
      ));
      return episode;
    } catch (error) {
      _setValue(value.copyWith(
        error: error.toString(),
        loadingEpisodeIds: value.loadingEpisodeIds
            .where((item) => item != episodeId)
            .toList(growable: false),
      ));
      return null;
    }
  }

  Future<List<EpisodeComment>?> loadEpisodeComments(int episodeId) async {
    if (value.episodeComments.containsKey(episodeId)) {
      return value.episodeComments[episodeId];
    }
    if (value.loadingEpisodeCommentIds.contains(episodeId)) {
      return null;
    }

    _setValue(value.copyWith(
      loadingEpisodeCommentIds: <int>[
        ...value.loadingEpisodeCommentIds,
        episodeId,
      ],
    ));
    try {
      final comments = await _privateRepository.getEpisodeComments(episodeId);
      _setValue(
        value.copyWith(
          episodeComments: <int, List<EpisodeComment>>{
            ...value.episodeComments,
            episodeId: comments,
          },
          loadingEpisodeCommentIds: value.loadingEpisodeCommentIds
              .where((item) => item != episodeId)
              .toList(growable: false),
        ),
      );
      return comments;
    } catch (error) {
      _setValue(
        value.copyWith(
          error: error.toString(),
          loadingEpisodeCommentIds: value.loadingEpisodeCommentIds
              .where((item) => item != episodeId)
              .toList(growable: false),
        ),
      );
      return null;
    }
  }

  Future<BlogEntry?> loadReviewEntry(int entryId) async {
    if (value.reviewEntries.containsKey(entryId)) {
      return value.reviewEntries[entryId];
    }
    if (value.loadingReviewEntryIds.contains(entryId)) {
      return null;
    }

    _setValue(
      value.copyWith(
        loadingReviewEntryIds: <int>[...value.loadingReviewEntryIds, entryId],
      ),
    );
    try {
      final entry = await _privateRepository.getBlogEntry(entryId);
      _setValue(
        value.copyWith(
          reviewEntries: <int, BlogEntry>{...value.reviewEntries, entryId: entry},
          loadingReviewEntryIds: value.loadingReviewEntryIds
              .where((item) => item != entryId)
              .toList(growable: false),
        ),
      );
      return entry;
    } catch (error) {
      _setValue(
        value.copyWith(
          error: error.toString(),
          loadingReviewEntryIds: value.loadingReviewEntryIds
              .where((item) => item != entryId)
              .toList(growable: false),
        ),
      );
      return null;
    }
  }

  Future<List<BlogComment>?> loadReviewComments(int entryId) async {
    if (value.reviewComments.containsKey(entryId)) {
      return value.reviewComments[entryId];
    }
    if (value.loadingReviewCommentIds.contains(entryId)) {
      return null;
    }

    _setValue(
      value.copyWith(
        loadingReviewCommentIds: <int>[
          ...value.loadingReviewCommentIds,
          entryId,
        ],
      ),
    );
    try {
      final comments = await _privateRepository.getBlogComments(entryId);
      _setValue(
        value.copyWith(
          reviewComments: <int, List<BlogComment>>{
            ...value.reviewComments,
            entryId: comments,
          },
          loadingReviewCommentIds: value.loadingReviewCommentIds
              .where((item) => item != entryId)
              .toList(growable: false),
        ),
      );
      return comments;
    } catch (error) {
      _setValue(
        value.copyWith(
          error: error.toString(),
          loadingReviewCommentIds: value.loadingReviewCommentIds
              .where((item) => item != entryId)
              .toList(growable: false),
        ),
      );
      return null;
    }
  }

  void _setValue(SubjectDetailState nextValue) {
    if (_isDisposed) {
      return;
    }
    value = nextValue;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

typedef SubjectDetailStoreFactory = SubjectDetailStore Function();
