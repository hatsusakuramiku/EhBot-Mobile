import 'package:ehbot_mobile/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('validateBaseUrl 接受 https 与带前缀的明文地址', () {
    expect(validateBaseUrl('https://ehbot.example.com'), isNull);
    expect(validateBaseUrl('http://192.168.1.5:8000/ehbot'), isNull);
  });

  test('validateBaseUrl 拒绝空、缺 scheme、带查询串', () {
    expect(validateBaseUrl(''), isNotNull);
    expect(validateBaseUrl('ehbot.example.com'), isNotNull);
    expect(validateBaseUrl('https://ehbot.example.com?x=1'), isNotNull);
  });

  test('parseBaseUrl 去掉裸斜杠、保留反代前缀', () {
    expect(parseBaseUrl('https://ehbot.example.com/')?.path, '');
    expect(parseBaseUrl('https://ehbot.example.com/ehbot')?.path, '/ehbot');
    expect(parseBaseUrl('不是地址'), isNull);
  });

  test('设置存取往返（含自签与超时）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await SettingsStore().save(
      const AppSettings(
        baseUrl: 'https://ehbot.example.com/ehbot',
        allowSelfSigned: true,
        certFingerprint: 'AB:CD',
        timeout: Duration(seconds: 30),
      ),
    );
    final AppSettings loaded = await SettingsStore().load();

    expect(loaded.baseUrl, 'https://ehbot.example.com/ehbot');
    expect(loaded.allowSelfSigned, isTrue);
    expect(loaded.certFingerprint, 'AB:CD');
    expect(loaded.timeout, const Duration(seconds: 30));
    expect(loaded.isConfigured, isTrue);
  });

  test('存储损坏时回落到默认设置', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.storageKey: 'not-json',
    });

    final AppSettings loaded = await SettingsStore().load();

    expect(loaded.baseUrl, '');
    expect(loaded.isConfigured, isFalse);
  });
}
