import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:macaron_girlfriend_run/data/synced_lyrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('时间标签排序、校正、空行与循环定位', () {
    final lines = SyncedLyrics.parse(
      '[ar:测试]\n[00:03.50][00:01.5]晨光\n[00:04.000]\n[00:09.4]归途',
      offset: const Duration(milliseconds: -500),
    );
    expect(lines.map((line) => line.time.inMilliseconds), [
      1000,
      3000,
      3500,
      8900,
    ]);
    expect(
      SyncedLyrics.lineAt(lines, const Duration(milliseconds: 999)),
      isNull,
    );
    expect(
      SyncedLyrics.lineAt(lines, const Duration(milliseconds: 1000)),
      '晨光',
    );
    expect(
      SyncedLyrics.lineAt(lines, const Duration(milliseconds: 3500)),
      isNull,
    );
    expect(
      SyncedLyrics.lineAt(lines, const Duration(milliseconds: 9000)),
      '归途',
    );
    expect(SyncedLyrics.lineAt(lines, Duration.zero), isNull);
  });

  test('获取成功后离线读取缓存，失败后可重试', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final lyrics = SyncedLyrics.forTesting((uri) async {
      calls++;
      if (calls == 1) return http.Response('', 503);
      expect(uri.host, 'lrclib.net');
      return http.Response.bytes(
        utf8.encode(jsonEncode({'syncedLyrics': '[00:01.00]晨光'})),
        200,
      );
    });
    expect(await lyrics.load(0), isEmpty);
    expect((await lyrics.load(0)).single.text, '晨光');
    final offline = SyncedLyrics.forTesting(
      (_) async => throw StateError('offline'),
    );
    expect((await offline.load(0)).single.text, '晨光');
    expect(calls, 2);
  });
}
