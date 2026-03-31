import 'package:flutter/widgets.dart';

import '../backend/api/bangumi_repository.dart';
import '../ui/state/chat_store.dart';
import '../ui/state/discovery_store.dart';
import '../ui/state/settings_store.dart';
import '../ui/state/subject_detail_store.dart';

class AppDependencies {
  const AppDependencies({
    required this.bangumiRepository,
    required this.discoveryStore,
    required this.chatStore,
    required this.settingsStore,
    required this.subjectDetailStoreFactory,
  });

  final BangumiRepository bangumiRepository;
  final DiscoveryStore discoveryStore;
  final ChatStore chatStore;
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
