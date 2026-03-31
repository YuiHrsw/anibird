import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

class BangumiApiException implements Exception {
  const BangumiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef HeaderProvider = Future<Map<String, String>> Function();

class BangumiApiClient {
  BangumiApiClient({required this.headerProvider, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  static const String baseUrl = 'https://api.bgm.tv';

  final HeaderProvider headerProvider;
  final HttpClient _httpClient;

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
    throw const BangumiApiException('Unexpected JSON object response.');
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
    throw const BangumiApiException('Unexpected JSON list response.');
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
    throw const BangumiApiException('Unexpected JSON object response.');
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final sanitizedQueryParameters = queryParameters == null
        ? null
        : <String, String>{
            for (final entry in queryParameters.entries)
              if (entry.value != null) entry.key: entry.value.toString(),
          };
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: sanitizedQueryParameters,
    );
    final request = await _httpClient
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 15));
    developer.log(
      'Sending Bangumi request: $method $uri',
      name: 'anibird.bangumi',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    final headers = await headerProvider();
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    if (body != null) {
      developer.log(
        'Bangumi request body: ${jsonEncode(body)}',
        name: 'anibird.bangumi',
      );
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response.transform(utf8.decoder).join();
    developer.log(
      'Bangumi response status=${response.statusCode} for $method $uri',
      name: 'anibird.bangumi',
    );
    if (response.statusCode >= 400) {
      developer.log('Bangumi error body: $text', name: 'anibird.bangumi');
      throw BangumiApiException(
        'Bangumi request failed (${response.statusCode}): $text',
      );
    }
    if (text.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(text);
  }
}
