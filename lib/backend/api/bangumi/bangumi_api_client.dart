import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

class BangumiApiException implements Exception {
  const BangumiApiException({
    required this.message,
    this.statusCode,
    this.path,
    this.responseBody,
    this.kind = BangumiApiExceptionKind.unknown,
  });

  final String message;
  final int? statusCode;
  final String? path;
  final String? responseBody;
  final BangumiApiExceptionKind kind;

  @override
  String toString() => message;
}

enum BangumiApiExceptionKind {
  network,
  timeout,
  http,
  invalidResponse,
  decode,
  unknown,
}

typedef HeaderProvider = Future<Map<String, String>> Function();
typedef BaseUrlProvider = Future<String> Function();

class BangumiApiClient {
  BangumiApiClient({
    required this.headerProvider,
    BaseUrlProvider? baseUrlProvider,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: defaultBaseUrl,
               connectTimeout: _requestTimeout,
               receiveTimeout: _requestTimeout,
               sendTimeout: _requestTimeout,
               headers: const {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json; charset=utf-8',
               },
               responseType: ResponseType.plain,
             ),
           ) {
    _dio.interceptors.add(_BangumiRequestInterceptor(headerProvider));
    _dio.interceptors.add(const _BangumiLoggingInterceptor());
    _baseUrlProvider = baseUrlProvider;
  }

  static const String defaultBaseUrl = 'https://api.bgm.tv';
  static const Duration _requestTimeout = Duration(seconds: 15);

  final HeaderProvider headerProvider;
  final Dio _dio;
  late final BaseUrlProvider? _baseUrlProvider;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw BangumiApiException(
      message: 'Bangumi 返回了非对象 JSON 响应。',
      path: path,
      kind: BangumiApiExceptionKind.invalidResponse,
    );
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
    if (response is List<dynamic>) {
      return response;
    }
    throw BangumiApiException(
      message: 'Bangumi 返回了非数组 JSON 响应。',
      path: path,
      kind: BangumiApiExceptionKind.invalidResponse,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(
      method: 'POST',
      path: path,
      queryParameters: queryParameters,
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw BangumiApiException(
      message: 'Bangumi 返回了非对象 JSON 响应。',
      path: path,
      kind: BangumiApiExceptionKind.invalidResponse,
    );
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final sanitizedQueryParameters = _sanitizeQueryParameters(queryParameters);

    try {
      final response = await _dio.request<String>(
        _buildRequestUri(await _resolveBaseUrl(), path).toString(),
        data: body,
        queryParameters: sanitizedQueryParameters,
        options: Options(method: method),
      );
      final text = response.data ?? '';
      if (text.isEmpty) {
        return <String, dynamic>{};
      }
      try {
        return jsonDecode(text);
      } on FormatException catch (error) {
        throw BangumiApiException(
          message: 'Bangumi 响应 JSON 解析失败：$error',
          path: path,
          responseBody: text,
          kind: BangumiApiExceptionKind.decode,
        );
      }
    } on DioException catch (error) {
      throw _mapDioException(error, path);
    }
  }

  Future<String> _resolveBaseUrl() async {
    final value = await _baseUrlProvider?.call();
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return defaultBaseUrl;
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _buildRequestUri(String baseUrl, String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(baseUrl).replace(
      pathSegments: [
        ...Uri.parse(baseUrl).pathSegments.where((segment) => segment.isNotEmpty),
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
      ],
    );
  }

  Map<String, dynamic>? _sanitizeQueryParameters(
    Map<String, dynamic>? queryParameters,
  ) {
    if (queryParameters == null) {
      return null;
    }
    return <String, dynamic>{
      for (final entry in queryParameters.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  BangumiApiException _mapDioException(DioException error, String path) {
    final statusCode = error.response?.statusCode;
    final rawBody = _responseBodyToString(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return BangumiApiException(
          message: 'Bangumi 请求超时，请稍后重试。',
          statusCode: statusCode,
          path: path,
          responseBody: rawBody,
          kind: BangumiApiExceptionKind.timeout,
        );
      case DioExceptionType.badResponse:
        return BangumiApiException(
          message: 'Bangumi request failed ($statusCode): ${rawBody ?? ''}'.trim(),
          statusCode: statusCode,
          path: path,
          responseBody: rawBody,
          kind: BangumiApiExceptionKind.http,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return BangumiApiException(
          message: 'Bangumi 网络连接失败：${error.message ?? 'unknown error'}',
          statusCode: statusCode,
          path: path,
          responseBody: rawBody,
          kind: BangumiApiExceptionKind.network,
        );
      case DioExceptionType.cancel:
        return BangumiApiException(
          message: 'Bangumi 请求已取消。',
          statusCode: statusCode,
          path: path,
          responseBody: rawBody,
          kind: BangumiApiExceptionKind.network,
        );
      case DioExceptionType.unknown:
        return BangumiApiException(
          message: 'Bangumi 请求失败：${error.message ?? error.error ?? 'unknown error'}',
          statusCode: statusCode,
          path: path,
          responseBody: rawBody,
          kind: BangumiApiExceptionKind.unknown,
        );
    }
  }

  String? _responseBodyToString(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      return data;
    }
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }
}

class _BangumiRequestInterceptor extends Interceptor {
  _BangumiRequestInterceptor(this._headerProvider);

  final HeaderProvider _headerProvider;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _headerProvider();
      options.headers.addAll(headers);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: 'Failed to build Bangumi request headers: $error',
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }

    if (options.data is Map<String, dynamic>) {
      developer.log(
        'Bangumi request body: ${jsonEncode(options.data)}',
        name: 'anibird.bangumi',
      );
    }

    handler.next(options);
  }
}

class _BangumiLoggingInterceptor extends Interceptor {
  const _BangumiLoggingInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      'Sending Bangumi request: ${options.method} ${options.uri}',
      name: 'anibird.bangumi',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    developer.log(
      'Bangumi response status=${response.statusCode} for ${response.requestOptions.method} ${response.requestOptions.uri}',
      name: 'anibird.bangumi',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      'Bangumi response status=${err.response?.statusCode} for ${err.requestOptions.method} ${err.requestOptions.uri}',
      name: 'anibird.bangumi',
    );
    final rawBody = err.response?.data;
    if (rawBody != null) {
      developer.log(
        'Bangumi error body: ${rawBody is String ? rawBody : jsonEncode(rawBody)}',
        name: 'anibird.bangumi',
      );
    }
    handler.next(err);
  }
}
