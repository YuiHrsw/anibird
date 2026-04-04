import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../backend/api/bangumi/bangumi_private_repository.dart';
import '../../backend/api/config/file_config_repository.dart';
import '../../backend/models/app_config.dart';
import '../../backend/models/bangumi_oauth_token.dart';
import '../../backend/models/bangumi_profile.dart';
import '../../backend/services/app_cache_service.dart';
import '../../backend/services/bangumi_oauth_service.dart';

@immutable
class SettingsState {
  const SettingsState({
    this.config = AppConfig.defaults,
    this.isLoaded = false,
    this.isSaving = false,
    this.error,
    this.bangumiProfile,
    this.isLoadingBangumiProfile = false,
    this.bangumiProfileError,
    this.isBangumiAuthorizing = false,
    this.bangumiAuthError,
    this.isClearingImageCache = false,
    this.isClearingAllCaches = false,
  });

  final AppConfig config;
  final bool isLoaded;
  final bool isSaving;
  final String? error;
  final BangumiProfile? bangumiProfile;
  final bool isLoadingBangumiProfile;
  final String? bangumiProfileError;
  final bool isBangumiAuthorizing;
  final String? bangumiAuthError;
  final bool isClearingImageCache;
  final bool isClearingAllCaches;

  SettingsState copyWith({
    AppConfig? config,
    bool? isLoaded,
    bool? isSaving,
    String? error,
    BangumiProfile? bangumiProfile,
    bool? isLoadingBangumiProfile,
    String? bangumiProfileError,
    bool? isBangumiAuthorizing,
    String? bangumiAuthError,
    bool? isClearingImageCache,
    bool? isClearingAllCaches,
    bool clearBangumiProfile = false,
    bool clearBangumiProfileError = false,
    bool clearBangumiAuthError = false,
    bool clearError = false,
  }) {
    return SettingsState(
      config: config ?? this.config,
      isLoaded: isLoaded ?? this.isLoaded,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
      bangumiProfile: clearBangumiProfile
          ? null
          : bangumiProfile ?? this.bangumiProfile,
      isLoadingBangumiProfile:
          isLoadingBangumiProfile ?? this.isLoadingBangumiProfile,
      bangumiProfileError: clearBangumiProfileError
          ? null
          : bangumiProfileError ?? this.bangumiProfileError,
      isBangumiAuthorizing:
          isBangumiAuthorizing ?? this.isBangumiAuthorizing,
      bangumiAuthError: clearBangumiAuthError
          ? null
          : bangumiAuthError ?? this.bangumiAuthError,
      isClearingImageCache:
          isClearingImageCache ?? this.isClearingImageCache,
      isClearingAllCaches: isClearingAllCaches ?? this.isClearingAllCaches,
    );
  }
}

class SettingsStore extends ValueNotifier<SettingsState> {
  SettingsStore(
    this._repository,
    this._bangumiPrivateRepository,
    this._bangumiOAuthService,
    this._appCacheService,
  ) : super(const SettingsState());

  final FileConfigRepository _repository;
  final BangumiPrivateRepository _bangumiPrivateRepository;
  final BangumiOAuthService _bangumiOAuthService;
  final AppCacheService _appCacheService;
  StreamSubscription<Uri>? _oauthCallbackSubscription;
  String? _pendingOauthState;
  String? _lastHandledOauthUri;

  Future<void> load() async {
    try {
      final config = await _repository.load();
      value = value.copyWith(config: config, isLoaded: true, clearError: true);
      await _ensureOauthListening();
      await refreshBangumiProfile(silentWhenMissingCredentials: true);
    } catch (error) {
      value = value.copyWith(
        isLoaded: true,
        error: error.toString(),
      );
    }
  }

  Future<void> save(AppConfig config) async {
    value = value.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.save(config);
      value = value.copyWith(
        config: config,
        isLoaded: true,
        isSaving: false,
        clearError: true,
      );
      await _ensureOauthListening();
      await refreshBangumiProfile(silentWhenMissingCredentials: true);
    } catch (error) {
      value = value.copyWith(isSaving: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> startBangumiOAuthLogin() async {
    final config = value.config;
    try {
      await _ensureOauthListening();
      final state = _bangumiOAuthService.generateState();
      _pendingOauthState = state;
      final uri = _bangumiOAuthService.buildAuthorizationUri(
        config,
        state: state,
      );
      value = value.copyWith(
        isBangumiAuthorizing: true,
        clearBangumiAuthError: true,
      );
      await _bangumiOAuthService.launchAuthorization(uri);
    } catch (error) {
      value = value.copyWith(
        isBangumiAuthorizing: false,
        bangumiAuthError: error.toString(),
      );
    }
  }

  Future<void> logoutBangumi() async {
    final nextConfig = value.config.copyWith(
      bangumiAccessToken: '',
      bangumiRefreshToken: '',
      bangumiAccessTokenExpiresAt: 0,
    );
    await _repository.save(nextConfig);
    value = value.copyWith(
      config: nextConfig,
      clearBangumiProfile: true,
      clearBangumiProfileError: true,
      clearBangumiAuthError: true,
      isBangumiAuthorizing: false,
    );
  }

  Future<void> refreshBangumiProfile({
    bool silentWhenMissingCredentials = false,
  }) async {
    final config = await _ensureValidBangumiAccessToken();
    if (config.bangumiPrivateApiBaseUrl.trim().isEmpty ||
        config.bangumiAccessToken.trim().isEmpty) {
      value = value.copyWith(
        isLoadingBangumiProfile: false,
        clearBangumiProfile: true,
        bangumiProfileError: silentWhenMissingCredentials
            ? null
            : '请先填写 Bangumi Private API Base URL 和 Access Token。',
        clearBangumiProfileError: silentWhenMissingCredentials,
      );
      return;
    }

    value = value.copyWith(
      isLoadingBangumiProfile: true,
      clearBangumiProfileError: true,
    );
    try {
      final profile = await _bangumiPrivateRepository.getCurrentUser();
      value = value.copyWith(
        bangumiProfile: profile,
        isLoadingBangumiProfile: false,
        clearBangumiProfileError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoadingBangumiProfile: false,
        clearBangumiProfile: true,
        bangumiProfileError: error.toString(),
      );
    }
  }

  Future<void> clearImageCache() async {
    value = value.copyWith(isClearingImageCache: true, clearError: true);
    try {
      await _appCacheService.clearImageCache();
      value = value.copyWith(isClearingImageCache: false, clearError: true);
    } catch (error) {
      value = value.copyWith(
        isClearingImageCache: false,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> clearAllCaches() async {
    value = value.copyWith(isClearingAllCaches: true, clearError: true);
    try {
      await _appCacheService.clearAllCaches();
      value = value.copyWith(isClearingAllCaches: false, clearError: true);
    } catch (error) {
      value = value.copyWith(
        isClearingAllCaches: false,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<AppConfig> _ensureValidBangumiAccessToken() async {
    final config = value.config;
    final now = DateTime.now().millisecondsSinceEpoch;
    final shouldRefresh =
        config.bangumiAccessToken.trim().isNotEmpty &&
        config.bangumiRefreshToken.trim().isNotEmpty &&
        config.bangumiAccessTokenExpiresAt > 0 &&
        config.bangumiAccessTokenExpiresAt <= now + const Duration(minutes: 1).inMilliseconds;
    if (!shouldRefresh) {
      return config;
    }
    try {
      final token = await _bangumiOAuthService.refreshAccessToken(config);
      return await _persistOAuthToken(token);
    } catch (error) {
      value = value.copyWith(bangumiAuthError: error.toString());
      return config;
    }
  }

  Future<void> _ensureOauthListening() async {
    _oauthCallbackSubscription ??= _bangumiOAuthService.callbackStream.listen(
      _handleOauthCallback,
      onError: (Object error, StackTrace stackTrace) {
        value = value.copyWith(
          isBangumiAuthorizing: false,
          bangumiAuthError: error.toString(),
        );
      },
    );
    final initialUri = await _bangumiOAuthService.getInitialCallbackUri();
    if (initialUri != null) {
      await _handleOauthCallback(initialUri);
    }
  }

  Future<void> _handleOauthCallback(Uri uri) async {
    final config = value.config;
    if (!_bangumiOAuthService.isOAuthCallback(uri, config)) {
      return;
    }
    if (_lastHandledOauthUri == uri.toString()) {
      return;
    }
    _lastHandledOauthUri = uri.toString();

    final code = uri.queryParameters['code']?.trim();
    final state = uri.queryParameters['state']?.trim();
    if (code == null || code.isEmpty) {
      value = value.copyWith(
        isBangumiAuthorizing: false,
        bangumiAuthError: 'Bangumi OAuth 回调缺少 code。',
      );
      return;
    }
    if (_pendingOauthState != null && state != _pendingOauthState) {
      value = value.copyWith(
        isBangumiAuthorizing: false,
        bangumiAuthError: 'Bangumi OAuth state 校验失败。',
      );
      return;
    }

    try {
      final token = await _bangumiOAuthService.exchangeAuthorizationCode(
        config: config,
        code: code,
      );
      await _persistOAuthToken(token);
      _pendingOauthState = null;
      value = value.copyWith(
        isBangumiAuthorizing: false,
        clearBangumiAuthError: true,
      );
      await refreshBangumiProfile();
    } catch (error) {
      value = value.copyWith(
        isBangumiAuthorizing: false,
        bangumiAuthError: error.toString(),
      );
    }
  }

  Future<AppConfig> _persistOAuthToken(BangumiOAuthToken token) async {
    final expiresAt = DateTime.now()
        .add(Duration(seconds: token.expiresIn))
        .millisecondsSinceEpoch;
    final nextConfig = value.config.copyWith(
      bangumiAccessToken: token.accessToken,
      bangumiRefreshToken: token.refreshToken,
      bangumiAccessTokenExpiresAt: expiresAt,
    );
    await _repository.save(nextConfig);
    value = value.copyWith(config: nextConfig);
    return nextConfig;
  }

  @override
  void dispose() {
    _oauthCallbackSubscription?.cancel();
    super.dispose();
  }
}
