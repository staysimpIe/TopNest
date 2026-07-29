import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/music_state.dart';

class WindowsMediaService {
  static const _channel = MethodChannel('topnest/appbar');

  Future<MusicState> getState() async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'getMediaState',
      );
      final map = value ?? const <Object?, Object?>{};
      final state = MusicState.fromMap(map);
      final isNetease =
          map['neteaseSession'] == true ||
          (!state.available && map['neteaseRunning'] == true);
      if (!isNetease) return state;
      final synchronizedState = state.copyWith(positionMs: state.rawPositionMs);
      return await _readNeteaseCache(
            windowTitle: map['windowTitle'] as String?,
            mediaState: synchronizedState,
          ) ??
          synchronizedState;
    } on PlatformException catch (error) {
      return MusicState(error: error.message ?? '读取媒体状态失败');
    }
  }

  Future<MusicState?> _readNeteaseCache({
    required String? windowTitle,
    required MusicState mediaState,
  }) async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) return null;
    try {
      final file = File(
        '$localAppData\\NetEase\\CloudMusic\\webdata\\file\\playingList',
      );
      final root = jsonDecode(await file.readAsString());
      if (root is! Map || root['list'] is! List) return null;
      final items = (root['list'] as List).whereType<Map>();
      final item = matchNeteaseTrack(
        items,
        mediaState,
        fallbackTitle: windowTitle,
      );
      final track = item?['track'];
      if (track is! Map) return null;
      final artists = track['artists'] is List
          ? (track['artists'] as List)
                .whereType<Map>()
                .map((artist) => artist['name'])
                .whereType<String>()
                .where((name) => name.isNotEmpty)
                .join(' / ')
          : '';
      final album = track['album'] is Map ? track['album'] as Map : null;
      final coverUrl =
          album?['cover'] as String? ?? album?['picUrl'] as String?;
      return MusicState(
        available: true,
        title: mediaState.title.isNotEmpty
            ? mediaState.title
            : track['name'] as String? ?? '',
        artist: mediaState.artist.isNotEmpty ? mediaState.artist : artists,
        album: mediaState.album.isNotEmpty
            ? mediaState.album
            : album?['name'] as String? ?? '',
        cover: mediaState.cover,
        coverUrl: coverUrl,
        playing: mediaState.playing,
        canPrevious: mediaState.available ? mediaState.canPrevious : true,
        canNext: mediaState.available ? mediaState.canNext : true,
        canPlayPause: mediaState.available ? mediaState.canPlayPause : true,
        trackId: track['id']?.toString(),
        positionMs: mediaState.positionMs,
        rawPositionMs: mediaState.rawPositionMs,
        audioActive: mediaState.audioActive,
        durationMs: mediaState.durationMs,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @visibleForTesting
  Map? matchNeteaseTrack(
    Iterable<Map> items,
    MusicState mediaState, {
    String? fallbackTitle,
  }) {
    final title = mediaState.title.isNotEmpty
        ? mediaState.title
        : fallbackTitle ?? '';
    final normalizedTitle = _normalizeMetadata(title);
    if (normalizedTitle.isEmpty) return null;

    Map? bestMatch;
    var bestScore = -1;
    for (final item in items) {
      final track = item['track'];
      if (track is! Map) continue;
      final candidateTitle = _normalizeMetadata(track['name'] as String? ?? '');
      if (candidateTitle.isEmpty) continue;

      var score = 0;
      if (normalizedTitle == candidateTitle) {
        score += 100;
      } else if (normalizedTitle.contains(candidateTitle) ||
          candidateTitle.contains(normalizedTitle)) {
        score += 60;
      } else {
        continue;
      }

      final normalizedArtist = _normalizeMetadata(mediaState.artist);
      if (normalizedArtist.isNotEmpty) {
        final artistMatched =
            track['artists'] is List &&
            (track['artists'] as List).whereType<Map>().any((artist) {
              final candidateArtist = _normalizeMetadata(
                artist['name'] as String? ?? '',
              );
              return candidateArtist.isNotEmpty &&
                  (normalizedArtist.contains(candidateArtist) ||
                      candidateArtist.contains(normalizedArtist));
            });
        score += artistMatched ? 40 : -60;
      }

      final album = track['album'];
      final candidateAlbum = album is Map
          ? _normalizeMetadata(album['name'] as String? ?? '')
          : '';
      final normalizedAlbum = _normalizeMetadata(mediaState.album);
      if (normalizedAlbum.isNotEmpty && normalizedAlbum == candidateAlbum) {
        score += 20;
      }

      final duration = (track['duration'] as num?)?.toInt();
      if (mediaState.durationMs > 0 && duration != null) {
        final difference = (mediaState.durationMs - duration).abs();
        if (difference <= 2000) {
          score += 30;
        } else if (difference <= 5000) {
          score += 20;
        } else if (difference <= 10000) {
          score += 10;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }
    return bestScore >= 100 ? bestMatch : null;
  }

  String _normalizeMetadata(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'''[\s\-‐‑‒–—―_·•.,，。:：;；'"’‘“”()（）\[\]【】{}]+'''), '')
      .trim();

  Future<void> previous() => _control('previous');
  Future<void> next() => _control('next');
  Future<void> togglePlayPause() => _control('playPause');
  Future<void> _control(String action) =>
      _channel.invokeMethod('mediaControl', {'action': action});
}
