import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_message.dart';
import 'result.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient(this.baseUrl, this.tokens, {this.onUnauthorized});

  final String baseUrl;
  final TokenStore tokens;
  final void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 8);

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await tokens.read() ?? ''}',
      };

  Future<String> _sessionDied() async {
    await tokens.clear();
    onUnauthorized?.call();
    return 'Сессия истекла — войдите снова';
  }

  Future<Result<T>> send<T>(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    int okStatus = 200,
    required T Function(dynamic json) parse,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final req = http.Request(method, uri)..headers.addAll(await _headers());
      if (body != null) req.body = jsonEncode(body);
      final res =
          await http.Response.fromStream(await req.send().timeout(_timeout))
              .timeout(_timeout);

      if (res.statusCode == 401) return Err(await _sessionDied());
      if (res.statusCode != okStatus) return Err(apiMessage(res));
      if (res.statusCode == 204) return Ok(parse(null));
      return Ok(parse(jsonDecode(utf8.decode(res.bodyBytes))));
    } on SocketException {
      return const Err('Нет сети — повторите попытку');
    } on TimeoutException {
      return const Err('Сервер не отвечает');
    } on http.ClientException {
      return const Err('Нет сети — повторите попытку');
    } on FormatException {
      return const Err('Ответ не тот, что обещан');
    } on TypeError {
      return const Err('Ответ не тот, что обещан');
    }
  }
}

List<T> itemsOf<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
    ((json as Map<String, dynamic>)['items'] as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
