import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_config.dart';
import '../models/bangumi_client_config.dart';
import '../models/bangumi_oauth_token.dart';

class BangumiOAuthException implements Exception {
  const BangumiOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BangumiOAuthService {
  BangumiOAuthService({
    required BangumiClientConfig clientConfig,
    AppLinks? appLinks,
    Dio? dio,
  }) : _clientConfig = clientConfig,
       _appLinks = appLinks ?? AppLinks(),
       _dio = dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               responseType: ResponseType.plain,
             ),
           );

  final BangumiClientConfig _clientConfig;
  final AppLinks _appLinks;
  final Dio _dio;

  Stream<Uri> get callbackStream => _appLinks.uriLinkStream;

  Future<Uri?> getInitialCallbackUri() => _appLinks.getInitialLink();

  String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Uri buildAuthorizationUri(AppConfig config, {required String state}) {
    _validateOAuthConfig();
    final uri = _oauthBaseUri().replace(
      pathSegments: [..._oauthBaseUri().pathSegments, 'authorize'],
      queryParameters: {
        'client_id': _clientConfig.oauthClientId.trim(),
        'response_type': 'code',
        'redirect_uri': BangumiClientConfig.oauthRedirectUri,
        'state': state,
      },
    );
    return uri;
  }

  bool isOAuthCallback(Uri uri, AppConfig config) {
    final redirect = Uri.tryParse(BangumiClientConfig.oauthRedirectUri);
    if (redirect == null) {
      return false;
    }
    return uri.scheme == redirect.scheme &&
        uri.host == redirect.host &&
        uri.path == redirect.path;
  }

  Future<void> launchAuthorization(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw const BangumiOAuthException('无法打开浏览器开始 Bangumi OAuth 登录。');
    }
  }

  Future<BangumiOAuthToken> exchangeAuthorizationCode({
    required AppConfig config,
    required String code,
  }) async {
    _validateOAuthConfig();
    return _postToken(
      data: <String, dynamic>{
        'grant_type': 'authorization_code',
        'client_id': _clientConfig.oauthClientId.trim(),
        'client_secret': _clientConfig.oauthClientSecret.trim(),
        'code': code,
        'redirect_uri': BangumiClientConfig.oauthRedirectUri,
      },
    );
  }

  Future<BangumiOAuthToken> refreshAccessToken(AppConfig config) async {
    _validateOAuthConfig();
    if (config.bangumiRefreshToken.trim().isEmpty) {
      throw const BangumiOAuthException('缺少 Bangumi refresh token。');
    }
    return _postToken(
      data: <String, dynamic>{
        'grant_type': 'refresh_token',
        'client_id': _clientConfig.oauthClientId.trim(),
        'client_secret': _clientConfig.oauthClientSecret.trim(),
        'refresh_token': config.bangumiRefreshToken.trim(),
        'redirect_uri': BangumiClientConfig.oauthRedirectUri,
      },
    );
  }

  Future<BangumiOAuthToken> _postToken({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<String>(
        _oauthBaseUri()
            .replace(pathSegments: [..._oauthBaseUri().pathSegments, 'access_token'])
            .toString(),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final text = response.data ?? '';
      if (text.isEmpty) {
        throw const BangumiOAuthException('Bangumi OAuth token 响应为空。');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const BangumiOAuthException('Bangumi OAuth token 响应格式无效。');
      }
      return BangumiOAuthToken.fromJson(decoded);
    } on DioException catch (error) {
      final body = error.response?.data?.toString() ?? error.message ?? 'unknown error';
      throw BangumiOAuthException('Bangumi OAuth token 请求失败：$body');
    } on FormatException catch (error) {
      throw BangumiOAuthException('Bangumi OAuth token 响应解析失败：$error');
    }
  }

  Uri _oauthBaseUri() {
    final base = Uri.parse(BangumiClientConfig.privateApiBaseUrl);
    final pathSegments = base.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (pathSegments.isNotEmpty && pathSegments.last == 'p1') {
      pathSegments.removeLast();
    }
    return base.replace(pathSegments: [...pathSegments, 'oauth']);
  }

  void _validateOAuthConfig() {
    if (_clientConfig.oauthClientId.trim().isEmpty) {
      throw const BangumiOAuthException('项目配置中缺少 Bangumi OAuth Client ID。');
    }
    if (_clientConfig.oauthClientSecret.trim().isEmpty) {
      throw const BangumiOAuthException(
        '项目配置中缺少 Bangumi OAuth Client Secret。',
      );
    }
  }
}
