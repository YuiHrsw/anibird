import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../backend/api/bangumi/bangumi_api_client.dart';
import '../backend/api/bangumi/bangumi_private_repository.dart';
import '../backend/api/bangumi/bangumi_repository.dart';
import '../backend/api/chat/file_chat_session_repository.dart';
import '../backend/api/config/bangumi_client_config_repository.dart';
import '../backend/api/config/file_config_repository.dart';
import '../backend/api/llm/openai_compatible_llm_provider.dart';
import '../backend/api/my_collections_cache_repository.dart';
import '../backend/models/bangumi_client_config.dart';
import '../backend/services/agent.dart';
import '../backend/services/app_cache_service.dart';
import '../backend/services/bangumi_oauth_service.dart';
import '../backend/services/bangumi_tools.dart';
import 'app_scope.dart';
import '../ui/state/chat_store.dart';
import '../ui/state/discovery_store.dart';
import '../ui/state/my_collections_store.dart';
import '../ui/state/settings_store.dart';
import '../ui/state/subject_detail_store.dart';
import '../ui/state/timeline_store.dart';

Future<AppDependencies> bootstrap() async {
  final bangumiClientConfig = await BangumiClientConfigRepository().load();
  final configRepository = await _createConfigRepository();
  final bangumiClient = BangumiApiClient(
    headerProvider: () async {
      return {'User-Agent': BangumiClientConfig.userAgent};
    },
  );
  final bangumiRepository = BangumiRepository(bangumiClient);
  final bangumiPrivateClient = BangumiApiClient(
    headerProvider: () async {
      final config = await configRepository.load();
      return {
        'User-Agent': BangumiClientConfig.userAgent,
        if (config.bangumiAccessToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${config.bangumiAccessToken.trim()}',
      };
    },
    baseUrlProvider: () async => BangumiClientConfig.privateApiBaseUrl,
  );
  final bangumiPrivateRepository = BangumiPrivateRepository(
    bangumiPrivateClient,
  );
  final bangumiOAuthService = BangumiOAuthService(
    clientConfig: bangumiClientConfig,
  );
  final llmProvider = OpenAICompatibleLlmProvider(configRepository);
  final discoveryStore = DiscoveryStore(bangumiRepository);
  final timelineStore = TimelineStore(bangumiPrivateRepository);
  final myCollectionsCacheRepository =
      await _createMyCollectionsCacheRepository();
  final myCollectionsStore = MyCollectionsStore(
    bangumiPrivateRepository,
    myCollectionsCacheRepository,
  );
  final appCacheService = AppCacheService(
    myCollectionsCacheRepository,
    clearVolatileCaches: myCollectionsStore.clearMemoryCache,
  );
  final settingsStore = SettingsStore(
    configRepository,
    bangumiPrivateRepository,
    bangumiOAuthService,
    appCacheService,
  );
  final agent = Agent(
    llmProvider: llmProvider,
    tools: buildBangumiTools(
      bangumiRepository,
      bangumiPrivateRepository,
      myCollectionsCacheRepository,
    ),
  );
  final chatSessionRepository = await _createChatSessionRepository();
  final chatStore = ChatStore(
    agent,
    bangumiRepository,
    chatSessionRepository,
    settingsStore,
  );
  await settingsStore.load();
  await chatStore.load();

  return AppDependencies(
    bangumiRepository: bangumiRepository,
    discoveryStore: discoveryStore,
    chatStore: chatStore,
    myCollectionsStore: myCollectionsStore,
    timelineStore: timelineStore,
    settingsStore: settingsStore,
    subjectDetailStoreFactory: () =>
        SubjectDetailStore(bangumiRepository, bangumiPrivateRepository),
  );
}

Future<MyCollectionsCacheRepository?>
_createMyCollectionsCacheRepository() async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File.fromUri(
      directory.uri.resolve('anibird_my_collections_cache.json'),
    );
    return MyCollectionsCacheRepository(file);
  } catch (_) {
    return null;
  }
}

Future<FileConfigRepository> _createConfigRepository() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File.fromUri(directory.uri.resolve('anibird_config.json'));
  return FileConfigRepository(file);
}

Future<FileChatSessionRepository> _createChatSessionRepository() async {
  final directory = await getApplicationDocumentsDirectory();
  final chatsDirectory = Directory.fromUri(directory.uri.resolve('chats/'));
  return FileChatSessionRepository(chatsDirectory);
}
