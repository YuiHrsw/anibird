import '../backend/api/bangumi/bangumi_api_client.dart';
import '../backend/api/bangumi_repository.dart';
import '../backend/api/config/file_config_repository.dart';
import '../backend/api/llm/openai_compatible_llm_provider.dart';
import '../backend/models/app_config.dart';
import '../backend/services/agent.dart';
import '../backend/services/bangumi_tools.dart';
import 'app_scope.dart';
import '../ui/state/chat_store.dart';
import '../ui/state/discovery_store.dart';
import '../ui/state/settings_store.dart';
import '../ui/state/subject_detail_store.dart';

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
  final llmProvider = OpenAICompatibleLlmProvider(configRepository);
  final agent = Agent(
    llmProvider: llmProvider,
    tools: buildBangumiTools(bangumiRepository),
  );
  final discoveryStore = DiscoveryStore(bangumiRepository);
  final chatStore = ChatStore(agent);
  final settingsStore = SettingsStore(configRepository);
  await settingsStore.load();

  return AppDependencies(
    bangumiRepository: bangumiRepository,
    discoveryStore: discoveryStore,
    chatStore: chatStore,
    settingsStore: settingsStore,
    subjectDetailStoreFactory: () => SubjectDetailStore(bangumiRepository),
  );
}
