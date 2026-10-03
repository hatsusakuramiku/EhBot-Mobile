import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// 把传输层异常统一成 [ApiException.networkFailure]，并统一超时。
Future<T> guardTransport<T>(
  Future<T> Function() action, {
  required Duration timeout,
}) async {
  try {
    return await action().timeout(timeout);
  } on TimeoutException {
    throw const ApiException(
      code: ApiException.networkFailure,
      message: '连接超时，请检查服务器地址与网络。',
    );
  } on HandshakeException catch (error) {
    throw ApiException(
      code: ApiException.networkFailure,
      message: 'TLS 握手失败：${error.message}（自签证书需在服务器设置里显式允许）。',
    );
  } on SocketException catch (error) {
    throw ApiException(
      code: ApiException.networkFailure,
      message: '无法连接服务器：${error.message}',
    );
  } on HttpException catch (error) {
    throw ApiException(
      code: ApiException.networkFailure,
      message: '连接中断：${error.message}',
    );
  } on http.ClientException catch (error) {
    throw ApiException(
      code: ApiException.networkFailure,
      message: error.message,
    );
  }
}
