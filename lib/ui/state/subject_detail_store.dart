import 'package:flutter/foundation.dart';

import '../../backend/api/bangumi_repository.dart';
import '../../backend/models/episode.dart';
import '../../backend/models/related_character.dart';
import '../../backend/models/related_person.dart';
import '../../backend/models/subject.dart';

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
    this.loadingEpisodeIds = const <int>[],
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
  final List<int> loadingEpisodeIds;
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
    List<int>? loadingEpisodeIds,
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
      loadingEpisodeIds: loadingEpisodeIds ?? this.loadingEpisodeIds,
      characters: characters ?? this.characters,
      persons: persons ?? this.persons,
    );
  }
}

class SubjectDetailStore extends ValueNotifier<SubjectDetailState> {
  SubjectDetailStore(this._repository) : super(const SubjectDetailState());

  final BangumiRepository _repository;

  Future<void> load(int subjectId) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final subject = await _repository.getSubjectDetail(subjectId);
      final relatedSubjects = await _repository.getRelatedSubjects(subjectId);
      final episodes = await _repository.getEpisodes(subjectId);
      final characters = await _repository.getRelatedCharacters(subjectId);
      final persons = await _repository.getRelatedPersons(subjectId);
      value = value.copyWith(
        isLoading: false,
        hasLoaded: true,
        subject: subject,
        relatedSubjects: relatedSubjects,
        episodes: episodes.data,
        characters: characters,
        persons: persons,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: error.toString(),
      );
    }
  }

  Future<Episode?> loadEpisodeDetail(int episodeId) async {
    if (value.episodeDetails.containsKey(episodeId)) {
      return value.episodeDetails[episodeId];
    }
    if (value.loadingEpisodeIds.contains(episodeId)) {
      return null;
    }

    value = value.copyWith(
      loadingEpisodeIds: <int>[...value.loadingEpisodeIds, episodeId],
    );
    try {
      final episode = await _repository.getEpisodeDetail(episodeId);
      final details = <int, Episode>{...value.episodeDetails, episodeId: episode};
      value = value.copyWith(
        episodeDetails: details,
        loadingEpisodeIds: value.loadingEpisodeIds
            .where((item) => item != episodeId)
            .toList(growable: false),
      );
      return episode;
    } catch (error) {
      value = value.copyWith(
        error: error.toString(),
        loadingEpisodeIds: value.loadingEpisodeIds
            .where((item) => item != episodeId)
            .toList(growable: false),
      );
      return null;
    }
  }
}

typedef SubjectDetailStoreFactory = SubjectDetailStore Function();
