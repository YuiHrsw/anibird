import '../backend/api/bangumi/bangumi_api_client.dart';
import '../backend/api/bangumi_private_repository.dart';
import '../backend/api/bangumi_repository.dart';
import '../backend/api/config/file_config_repository.dart';
import '../backend/api/llm/openai_compatible_llm_provider.dart';
import '../backend/api/my_collections_cache_repository.dart';
import '../backend/models/app_config.dart';
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
  final configRepository = FileConfigRepository();
  final bangumiClient = BangumiApiClient(
    headerProvider: () async {
      final config = await configRepository.load();
      return {
        'User-Agent': config.bangumiUserAgent.isEmpty
            ? AppConfig.defaults.bangumiUserAgent
            : config.bangumiUserAgent,
      };
    },
  );
  final bangumiRepository = BangumiRepository(bangumiClient);
  final bangumiPrivateClient = BangumiApiClient(
    headerProvider: () async {
      final config = await configRepository.load();
      return {
        'User-Agent': config.bangumiUserAgent.isEmpty
            ? AppConfig.defaults.bangumiUserAgent
            : config.bangumiUserAgent,
        if (config.bangumiAccessToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${config.bangumiAccessToken.trim()}',
      };
    },
    baseUrlProvider: () async {
      final config = await configRepository.load();
      return config.bangumiPrivateApiBaseUrl;
    },
  );
  final bangumiPrivateRepository = BangumiPrivateRepository(
    bangumiPrivateClient,
  );
  final bangumiOAuthService = BangumiOAuthService();
  final llmProvider = OpenAICompatibleLlmProvider(configRepository);
  final agent = Agent(
    llmProvider: llmProvider,
    tools: buildBangumiTools(bangumiRepository),
  );
  final discoveryStore = DiscoveryStore(bangumiRepository);
  final chatStore = ChatStore(agent, bangumiRepository);
  final timelineStore = TimelineStore(bangumiPrivateRepository);
  final myCollectionsCacheRepository = MyCollectionsCacheRepository();
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
  await settingsStore.load();

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
