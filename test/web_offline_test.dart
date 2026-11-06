// 离线与局域网验收测试（静态部分），对应 docs/离线与局域网/需求与接口.md。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('O1 入口脚本地址固定，不带时间戳', () {
    final html = _read('web/index.html');
    expect(html, contains("'flutter_bootstrap.js'"));
    expect(html, isNot(contains("flutter_bootstrap.js?load=")));
  });

  test('O2 版本键有本地兜底', () {
    final js = _read('web/flutter_bootstrap.js');
    expect(js, contains('macaron.build'));
    expect(js, contains('localStorage'));
    expect(js, contains('Date.now()'));
  });

  test('O3 注册 Service Worker，且策略正确', () {
    final boot = _read('web/flutter_bootstrap.js');
    expect(boot, contains('serviceWorker'));
    expect(boot, contains('offline_sw.js'));
    final sw = _read('web/offline_sw.js');
    expect(sw, contains('macaron-offline-v1'));
    expect(sw, contains('ignoreSearch: true'));
    expect(sw, contains('Range'));
    expect(sw, contains('206'));
    expect(sw, contains('skipWaiting'));
    expect(sw, contains('clients.claim'));
    expect(sw, contains("request.method !== 'GET'"));
  });

  test('O4 首帧后预热资源', () {
    final boot = _read('web/flutter_bootstrap.js');
    expect(boot, contains('macaron.warm'));
    expect(boot, contains('AssetManifest.json'));
    expect(boot, contains('flutter-first-frame'));
    expect(boot, contains('saveData'));
  });

  test('离线字体清单覆盖所有本地回退字体', () {
    final expected = Directory('web/fonts')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.woff2'))
        .map((file) => file.path.substring('web/'.length))
        .toSet();
    final actual = (jsonDecode(_read('web/offline_fonts.json')) as List)
        .cast<String>();
    expect(actual.toSet(), expected);
    expect(actual.length, expected.length);
  });

  test('O5 web 目录不依赖外网地址', () {
    final urlPattern = RegExp(r'https?://[^\s"\x27)]+');
    for (final entity in Directory('web').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!(path.endsWith('.html') || path.endsWith('.js'))) continue;
      for (final m in urlPattern.allMatches(entity.readAsStringSync())) {
        expect(
          m.group(0)!.contains('www.w3.org'),
          isTrue,
          reason: '$path 引用了外部地址 ${m.group(0)}',
        );
      }
    }
  });

  test('O6 局域网脚本存在、可执行、命令完整', () {
    final file = File('scripts/serve_lan.sh');
    expect(file.existsSync(), isTrue);
    final mode = file.statSync().mode;
    expect(mode & 0x40, isNot(0), reason: '需要可执行权限');
    final text = file.readAsStringSync();
    expect(
      text,
      contains(
        'flutter build web --release --no-web-resources-cdn --no-wasm-dry-run',
      ),
    );
    expect(text, contains('--no-build'));
    expect(text, contains('python3 scripts/serve_lan.py'));
    final server = _read('scripts/serve_lan.py');
    expect(server, contains('ssl.PROTOCOL_TLS_SERVER'));
    expect(server, contains('证书信任设置'));
    expect(server, contains('添加到主屏幕'));
  });

  test('局域网证书可验证并且私钥不放在网页目录', () async {
    final temp = await Directory.systemTemp.createTemp('macaron-cert-test-');
    try {
      final code = '''
import scripts.serve_lan as lan
import subprocess
ca, cert, key = lan.certificates(['127.0.0.2'])
assert ca.exists() and cert.exists() and key.exists()
assert not key.is_relative_to(lan.ROOT / 'build' / 'web')
assert key.stat().st_mode & 0o077 == 0
subprocess.run(['openssl', 'verify', '-CAfile', str(lan.CERT_DIR / 'ca.pem'), str(cert)], check=True, capture_output=True)
first = (lan.CERT_DIR / 'ca.pem').read_bytes()
lan.certificates(['127.0.0.3'])
assert (lan.CERT_DIR / 'ca.pem').read_bytes() == first
''';
      final result = await Process.run(
        'python3',
        ['-c', code],
        environment: {...Platform.environment, 'HOME': temp.path},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
