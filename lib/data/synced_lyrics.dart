import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

class SyncedLyrics {
  SyncedLyrics._() : _fetch = http.get;
  SyncedLyrics.forTesting(this._fetch);
  static final SyncedLyrics instance = SyncedLyrics._();
  final Future<http.Response> Function(Uri) _fetch;

  // IDs match the artist and duration of the bundled recordings.
  static const _recordIds = <int, int>{
    0: 38053871,
    1: 16519941,
    2: 40116292,
    3: 24754102,
    4: 18215880,
    5: 38503606,
  };
  static const _offsets = <int, Duration>{2: Duration(milliseconds: -2960)};
  final _pending = <int, Future<List<LyricLine>>>{};

  Future<List<LyricLine>> load(int song) {
    final existing = _pending[song];
    if (existing != null) return existing;
    final pending = _load(song);
    _pending[song] = pending;
    pending.then(
      (value) {
        if (value.isEmpty) _pending.remove(song);
      },
      onError: (Object _) {
        _pending.remove(song);
      },
    );
    return pending;
  }

  Future<List<LyricLine>> _load(int song) async {
    final id = _recordIds[song];
    if (id == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'synced_lyrics_$id';
      final cached = prefs.getString(key);
      if (cached != null) {
        final parsed = parse(cached, offset: _offsets[song] ?? Duration.zero);
        if (parsed.isNotEmpty) return parsed;
      }
      final response = await _fetch(
        Uri.https('lrclib.net', '/api/get/$id'),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final lrc = json is Map ? json['syncedLyrics'] : null;
      if (lrc is! String || lrc.length > 200000) return const [];
      final parsed = parse(lrc, offset: _offsets[song] ?? Duration.zero);
      if (parsed.isNotEmpty) await prefs.setString(key, lrc);
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  static List<LyricLine> parse(
    String source, {
    Duration offset = Duration.zero,
  }) {
    final result = <LyricLine>[];
    final stamps = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    for (final line in const LineSplitter().convert(source)) {
      final matches = stamps.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.substring(matches.last.end).trim();
      for (final match in matches) {
        final minute = int.parse(match[1]!);
        final second = int.parse(match[2]!);
        if (second >= 60) continue;
        final fraction = (match[3] ?? '').padRight(3, '0');
        result.add(
          LyricLine(
            Duration(
              milliseconds:
                  ((minute * 60 + second) * 1000 +
                          int.parse(fraction) +
                          offset.inMilliseconds)
                      .clamp(0, 1 << 31),
            ),
            text,
          ),
        );
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return List.unmodifiable(result);
  }

  static String? lineAt(List<LyricLine> lines, Duration position) {
    var low = 0;
    var high = lines.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == 0 || lines[low - 1].text.isEmpty) return null;
    return lines[low - 1].text;
  }
}
