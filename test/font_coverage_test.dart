// 字体覆盖验收测试，对应 docs/字体与标题/需求与接口.md 的 F1。
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _fontFiles = [
  'assets/fonts/NotoSansSC-Regular.ttf',
  'assets/fonts/NotoSansSC-Bold.ttf',
];

const _chinesePunctuation = '，。、；：？！“”‘’（）《》【】「」…—～·';
final _punctuation = _chinesePunctuation.runes.toSet();
final _identChar = RegExp(r'[A-Za-z0-9_$]');

bool _needsCoverage(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) || _punctuation.contains(rune);

/// 只读 cmap 的格式 4 与 12 子表，判断码点是否映射到非 0 字形。
class _TtfCmap {
  _TtfCmap._(this._data, this._subtables);

  factory _TtfCmap.parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final cmap = _tableOffset(data, 'cmap');
    final subtables = <int>[];
    for (var i = 0; i < data.getUint16(cmap + 2); i++) {
      final record = cmap + 4 + i * 8;
      final platform = data.getUint16(record);
      final encoding = data.getUint16(record + 2);
      final unicode =
          platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      final subtable = cmap + data.getUint32(record + 4);
      if (unicode && const {4, 12}.contains(data.getUint16(subtable))) {
        subtables.add(subtable);
      }
    }
    if (subtables.isEmpty) throw StateError('字体没有 Unicode 格式 4/12 的 cmap');
    return _TtfCmap._(data, subtables);
  }

  final ByteData _data;
  final List<int> _subtables;

  bool covers(int rune) => _subtables.any((sub) => _glyph(sub, rune) != 0);

  static int _tableOffset(ByteData data, String tag) {
    for (var i = 0; i < data.getUint16(4); i++) {
      final record = 12 + i * 16;
      final name = String.fromCharCodes(
        Iterable.generate(4, (k) => data.getUint8(record + k)),
      );
      if (name == tag) return data.getUint32(record + 8);
    }
    throw StateError('字体缺少 $tag 表');
  }

  int _glyph(int sub, int rune) =>
      _data.getUint16(sub) == 4 ? _format4(sub, rune) : _format12(sub, rune);

  int _format4(int sub, int rune) {
    if (rune > 0xFFFF) return 0;
    final segments = _data.getUint16(sub + 6) ~/ 2;
    final ends = sub + 14;
    final starts = ends + segments * 2 + 2;
    final deltas = starts + segments * 2;
    final rangeOffsets = deltas + segments * 2;
    for (var seg = 0; seg < segments; seg++) {
      if (rune > _data.getUint16(ends + seg * 2)) continue;
      final start = _data.getUint16(starts + seg * 2);
      if (rune < start) return 0;
      final delta = _data.getUint16(deltas + seg * 2);
      final rangeOffset = _data.getUint16(rangeOffsets + seg * 2);
      if (rangeOffset == 0) return (rune + delta) & 0xFFFF;
      final glyph = _data.getUint16(
        rangeOffsets + seg * 2 + rangeOffset + (rune - start) * 2,
      );
      return glyph == 0 ? 0 : (glyph + delta) & 0xFFFF;
    }
    return 0;
  }

  int _format12(int sub, int rune) {
    for (var g = 0; g < _data.getUint32(sub + 12); g++) {
      final group = sub + 16 + g * 12;
      final start = _data.getUint32(group);
      if (rune < start) return 0;
      if (rune <= _data.getUint32(group + 4)) {
        return _data.getUint32(group + 8) + rune - start;
      }
    }
    return 0;
  }
}

/// 取出 Dart 源码中所有字符串字面量的正文：解码 \u 与 \x 转义，跳过注释。
/// ${} 里的代码照常扫描，其中的字符串同样计入；原始字符串 r'' 不做转义和插值。
class _DartStrings {
  _DartStrings(this._src);

  final String _src;
  final _out = StringBuffer();
  var _pos = 0;

  String read() {
    _code(inInterpolation: false);
    return _out.toString();
  }

  void _code({required bool inInterpolation}) {
    var braces = 0;
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (_src.startsWith('//', _pos)) {
        final end = _src.indexOf('\n', _pos);
        _pos = end < 0 ? _src.length : end;
      } else if (_src.startsWith('/*', _pos)) {
        _blockComment();
      } else if (c == "'" || c == '"') {
        _string(raw: false);
      } else if (c == 'r' &&
          _pos + 1 < _src.length &&
          (_src[_pos + 1] == "'" || _src[_pos + 1] == '"')) {
        _pos++;
        _string(raw: true);
      } else if (_identChar.hasMatch(c)) {
        _skipIdent();
      } else {
        _pos++;
        if (inInterpolation && c == '{') braces++;
        if (inInterpolation && c == '}') {
          if (braces == 0) return;
          braces--;
        }
      }
    }
  }

  void _string({required bool raw}) {
    final quote = _src[_pos];
    final delimiter = _src.startsWith(quote * 3, _pos) ? quote * 3 : quote;
    final multiLine = delimiter.length == 3;
    _pos += delimiter.length;
    while (_pos < _src.length) {
      if (_src.startsWith(delimiter, _pos)) {
        _pos += delimiter.length;
        return;
      }
      final c = _src[_pos];
      if (!multiLine && c == '\n') return;
      if (!raw && c == r'\') {
        _escape();
      } else if (!raw && c == r'$' && _src.startsWith('{', _pos + 1)) {
        _pos += 2;
        _code(inInterpolation: true);
      } else if (!raw &&
          c == r'$' &&
          _pos + 1 < _src.length &&
          _identChar.hasMatch(_src[_pos + 1])) {
        _pos++;
        _skipIdent();
      } else {
        _out.write(c);
        _pos++;
      }
    }
  }

  void _escape() {
    final c = _src[++_pos];
    if (c == 'u' && _src.startsWith('{', _pos + 1)) {
      final end = _src.indexOf('}', _pos);
      _out.writeCharCode(int.parse(_src.substring(_pos + 2, end), radix: 16));
      _pos = end + 1;
    } else if (c == 'u' || c == 'x') {
      final width = c == 'u' ? 4 : 2;
      _out.writeCharCode(
        int.parse(_src.substring(_pos + 1, _pos + 1 + width), radix: 16),
      );
      _pos += 1 + width;
    } else {
      _out.write(c);
      _pos++;
    }
  }

  void _blockComment() {
    var depth = 0;
    while (_pos < _src.length) {
      if (_src.startsWith('/*', _pos)) {
        depth++;
        _pos += 2;
      } else if (_src.startsWith('*/', _pos)) {
        depth--;
        _pos += 2;
        if (depth == 0) return;
      } else {
        _pos++;
      }
    }
  }

  void _skipIdent() {
    while (_pos < _src.length && _identChar.hasMatch(_src[_pos])) {
      _pos++;
    }
  }
}

void main() {
  final cmaps = {
    for (final path in _fontFiles)
      path: _TtfCmap.parse(File(path).readAsBytesSync()),
  };
  final sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('源码是有效 UTF-8 且没有替换字符，完整字体覆盖额外汉字', () {
    for (final file in sources) {
      final content = utf8.decode(file.readAsBytesSync());
      expect(
        content.contains(String.fromCharCode(0xfffd)),
        isFalse,
        reason: file.path,
      );
    }
    final full = _TtfCmap.parse(
      File('assets/fonts/NotoSansSC-Full.ttf').readAsBytesSync(),
    );
    for (final rune in '龘麤齉'.runes) {
      expect(full.covers(rune), isTrue, reason: String.fromCharCode(rune));
    }
  });

  test('字符串扫描跳过注释并解码转义和插值', () {
    expect(
      _DartStrings(r"""
const a = '甲中'; // 乙
/* 丙 */ final b = r'丁\n' + "戊${'己'}庚";
final c = '''四''';
""").read(),
      '甲中丁\\n戊己庚四',
    );
  });

  test('lib 字符串里的汉字和中文标点在两个字体里都有字形', () {
    final filesByRune = <int, Set<String>>{};
    for (final file in sources) {
      for (final rune in _DartStrings(file.readAsStringSync()).read().runes) {
        if (_needsCoverage(rune)) {
          (filesByRune[rune] ??= {}).add(file.path);
        }
      }
    }
    expect(filesByRune, isNotEmpty, reason: '没有扫描到任何汉字，扫描器可能失效');

    final report = <String>[];
    for (final rune in filesByRune.keys.toList()..sort()) {
      final absent = [
        for (final font in cmaps.entries)
          if (!font.value.covers(rune)) font.key,
      ];
      if (absent.isEmpty) continue;
      final hex = rune.toRadixString(16).toUpperCase();
      report.add(
        '“${String.fromCharCode(rune)}” U+$hex 不在 ${absent.join('、')} 中，'
        '出现于 ${filesByRune[rune]!.join('、')}',
      );
    }
    expect(report, isEmpty, reason: '缺字 ${report.length} 个，改文案而非改字体');
  });
}
