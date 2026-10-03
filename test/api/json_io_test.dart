import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/json_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/http_stubs.dart';

void main() {
  test('2xx 直接返回', () {
    final http.Response response = jsonResponse(<String, Object?>{'ok': true});
    expect(ensureSuccess(response), same(response));
  });

  test('错误信封解析成 ApiException', () {
    final http.Response response = errorResponse(
      'AUTH_INVALID_CREDENTIALS',
      message: '密码错误',
      status: 401,
      details: <String, Object?>{'attempts': 3},
    );

    final ApiException error = errorFromResponse(response);

    expect(error.code, 'AUTH_INVALID_CREDENTIALS');
    expect(error.message, '密码错误');
    expect(error.statusCode, 401);
    expect(error.details, <String, Object?>{'attempts': 3});
  });

  test('非 JSON 错误体回落到 HTTP_<status>', () {
    final ApiException error = errorFromResponse(
      http.Response('<html>502</html>', 502),
    );
    expect(error.code, 'HTTP_502');
    expect(error.statusCode, 502);
  });

  test('items 缺失时抛 invalidResponse', () {
    expect(
      () => decodeItems(<String, dynamic>{'total': 0}),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.code,
          'code',
          ApiException.invalidResponse,
        ),
      ),
    );
  });
}
