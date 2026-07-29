import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/music_state.dart';

class LyricsService {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  Future<List<LyricLine>> load(MusicState state) async {
    final trackId = state.trackId;
    if (trackId != null && trackId.isNotEmpty) {
      try {
        final lyrics = await _loadNetease(trackId);
        if (lyrics.isNotEmpty) return lyrics;
      } catch (error) {
        debugPrint('网易云精确歌词读取失败，改用通用歌词源：$error');
      }
    }
    return _loadLrclib(state);
  }

  Future<List<LyricLine>> _loadNetease(String trackId) async {
    final uri = Uri.https('music.163.com', '/api/song/lyric', {
      'id': trackId,
      'lv': '-1',
      'kv': '-1',
      'tv': '-1',
    });
    final root = await _getJson(uri, referer: 'https://music.163.com/');
    final lyric = root is Map && root['lrc'] is Map
        ? (root['lrc'] as Map)['lyric'] as String?
        : null;
    return lyric == null || lyric.trim().isEmpty ? const [] : parse(lyric);
  }

  Future<List<LyricLine>> _loadLrclib(MusicState state) async {
    final query = <String, String>{
      'track_name': state.title,
      if (state.artist.isNotEmpty) 'artist_name': state.artist,
      if (state.album.isNotEmpty) 'album_name': state.album,
    };
    final root = await _getJson(Uri.https('lrclib.net', '/api/search', query));
    if (root is! List) return const [];
    final lyric = selectBestSyncedLyrics(root, state);
    return lyric == null ? const [] : parse(lyric);
  }

  Future<Object?> _getJson(Uri uri, {String? referer}) async {
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'TopNest/1.0');
    if (referer != null) {
      request.headers.set(HttpHeaders.refererHeader, referer);
    }
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('歌词请求失败：${response.statusCode}', uri: uri);
    }
    final body = await utf8.decoder.bind(response).join();
    return jsonDecode(body);
  }

  @visibleForTesting
  String? selectBestSyncedLyrics(List<Object?> candidates, MusicState state) {
    Map<Object?, Object?>? best;
    var bestScore = -1;
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final item = candidate.cast<Object?, Object?>();
      final syncedLyrics = item['syncedLyrics']?.toString();
      if (syncedLyrics == null || syncedLyrics.trim().isEmpty) continue;
      final score = _score(item, state);
      if (score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    return bestScore >= 100 && best != null
        ? best['syncedLyrics']?.toString()
        : null;
  }

  int _score(Map<Object?, Object?> item, MusicState state) {
    final wantedTitle = _normalize(state.title);
    final title = _normalize(item['trackName']?.toString() ?? '');
    if (wantedTitle.isEmpty || title.isEmpty) return -1;

    var score = 0;
    if (title == wantedTitle) {
      score += 100;
    } else if (title.contains(wantedTitle) || wantedTitle.contains(title)) {
      score += 70;
    } else {
      return -1;
    }

    final wantedArtist = _normalize(state.artist);
    final artist = _normalize(item['artistName']?.toString() ?? '');
    if (wantedArtist.isNotEmpty && artist.isNotEmpty) {
      if (artist == wantedArtist) {
        score += 50;
      } else if (artist.contains(wantedArtist) ||
          wantedArtist.contains(artist)) {
        score += 30;
      } else {
        score -= 30;
      }
    }

    final wantedAlbum = _normalize(state.album);
    final album = _normalize(item['albumName']?.toString() ?? '');
    if (wantedAlbum.isNotEmpty && wantedAlbum == album) score += 20;

    final duration = (item['duration'] as num?)?.round();
    if (state.durationMs > 0 && duration != null) {
      final difference = (duration - state.durationMs ~/ 1000).abs();
      if (difference <= 2) {
        score += 30;
      } else if (difference <= 5) {
        score += 20;
      } else if (difference <= 10) {
        score += 10;
      } else {
        score -= 20;
      }
    }
    return score;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'''[-_.,·•:：/\\()\[\]{}（）【】'"“”‘’]'''), '');

  List<LyricLine> parse(String source) {
    final result = <LyricLine>[];
    final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final rawLine in const LineSplitter().convert(source)) {
      final matches = timestamp.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;
      final text = rawLine.replaceAll(timestamp, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3) ?? '0';
        final milliseconds = switch (fraction.length) {
          1 => int.parse(fraction) * 100,
          2 => int.parse(fraction) * 10,
          _ => int.parse(fraction.substring(0, 3)),
        };
        result.add(
          LyricLine(
            timeMs: (minutes * 60 + seconds) * 1000 + milliseconds,
            text: text,
          ),
        );
      }
    }
    result.sort((left, right) => left.timeMs.compareTo(right.timeMs));
    return result;
  }

  void dispose() => _client.close(force: true);
}
