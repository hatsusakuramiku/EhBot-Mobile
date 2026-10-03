import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// 解码 2xx 的 JSON 响应体；不是 JSON 对象时抛 [ApiException]。
Map<String, dynamic> decodeJsonObject(http.Response response) {
  final Object? decoded = _decodeBody(response);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw ApiException(
    code: ApiException.invalidResponse,
    message: '服务器返回了无法解析的响应。',
    statusCode: response.statusCode,
  );
}

/// 取列表信封里的 `items`（`CONTRACT.md` §1）。
List<Map<String, dynamic>> decodeItems(Map<String, dynamic> json) {
  final Object? items = json['items'];
  if (items is! List) {
    throw const ApiException(
      code: ApiException.invalidResponse,
      message: '响应缺少 items 列表。',
    );
  }
  return items.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

/// 把非 2xx 响应转成 [ApiException]，解析后端错误信封。
ApiException errorFromResponse(http.Response response) {
  final Object? decoded = _decodeBody(response);
  if (decoded is Map) {
    final Object? error = decoded['error'];
    if (error is Map) {
      return ApiException(
        code: error['code'] as String? ?? 'HTTP_${response.statusCode}',
        message: error['message'] as String? ?? '请求失败。',
        statusCode: response.statusCode,
        details: error['details'],
      );
    }
  }
  return ApiException(
    code: 'HTTP_${response.statusCode}',
    message: '请求失败（HTTP ${response.statusCode}）。',
    statusCode: response.statusCode,
  );
}

/// 2xx 原样返回，否则抛 [ApiException]。
http.Response ensureSuccess(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return response;
  }
  throw errorFromResponse(response);
}

Object? _decodeBody(http.Response response) {
  if (response.bodyBytes.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    return null;
  }
}
