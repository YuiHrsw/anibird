import 'package:flutter/widgets.dart';

import '../backend/api/bangumi/bangumi_repository.dart';
import '../ui/state/chat_store.dart';
import '../ui/state/discovery_store.dart';
import '../ui/state/my_collections_store.dart';
import '../ui/state/settings_store.dart';
import '../ui/state/subject_detail_store.dart';
import '../ui/state/timeline_store.dart';

class AppDependencies {
  const AppDependencies({
    required this.bangumiRepository,
    required this.discoveryStore,
    required this.chatStore,
    required this.myCollectionsStore,
    required this.timelineStore,
    required this.settingsStore,
    required this.subjectDetailStoreFactory,
  });

  final BangumiRepository bangumiRepository;
  final DiscoveryStore discoveryStore;
  final ChatStore chatStore;
  final MyCollectionsStore myCollectionsStore;
  final TimelineStore timelineStore;
  final SettingsStore settingsStore;
  final SubjectDetailStoreFactory subjectDetailStoreFactory;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.dependencies != dependencies;
}

extension AppScopeBuildContext on BuildContext {
  AppDependencies get appDependencies {
    final scope = dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree.');
    return scope!.dependencies;
  }

  AppDependencies get readAppDependencies {
    final scope =
        getElementForInheritedWidgetOfExactType<AppScope>()?.widget as AppScope?;
    assert(scope != null, 'AppScope not found in widget tree.');
    return scope!.dependencies;
  }

  BangumiRepository get bangumiRepository => appDependencies.bangumiRepository;
  DiscoveryStore get discoveryStore => appDependencies.discoveryStore;
  ChatStore get chatStore => appDependencies.chatStore;
  MyCollectionsStore get myCollectionsStore => appDependencies.myCollectionsStore;
  TimelineStore get timelineStore => appDependencies.timelineStore;
  SettingsStore get settingsStore => appDependencies.settingsStore;
  SubjectDetailStoreFactory get subjectDetailStoreFactory =>
      appDependencies.subjectDetailStoreFactory;
}
