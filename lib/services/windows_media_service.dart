import 'dart:convert';
import 'dart:io';

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
      if (state.available || map['neteaseRunning'] != true) return state;
      return await _readNeteaseCache(
            windowTitle: map['windowTitle'] as String?,
            playing: map['playing'] == true,
          ) ??
          state;
    } on PlatformException catch (error) {
      return MusicState(error: error.message ?? '读取媒体状态失败');
    }
  }

  Future<MusicState?> _readNeteaseCache({
    required String? windowTitle,
    required bool playing,
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
      Map? item;
      if (windowTitle != null && windowTitle.isNotEmpty) {
        final normalizedTitle = _normalizeTitle(windowTitle);
        var matchedNameLength = -1;
        for (final candidate in items) {
          final candidateTrack = candidate['track'];
          if (candidateTrack is! Map) continue;
          final name = candidateTrack['name'] as String?;
          if (name == null || name.isEmpty) continue;
          final normalizedName = _normalizeTitle(name);
          final matches =
              normalizedTitle == normalizedName ||
              normalizedTitle.startsWith('$normalizedName - ') ||
              normalizedTitle.startsWith('$normalizedName – ') ||
              normalizedTitle.startsWith('$normalizedName — ');
          if (matches && normalizedName.length > matchedNameLength) {
            item = candidate;
            matchedNameLength = normalizedName.length;
          }
        }
      }
      item ??= items.cast<Map?>().firstWhere(
        (value) => value?['isPlayedOnce'] == true,
        orElse: () => items.isEmpty ? null : items.first,
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
        title: track['name'] as String? ?? '',
        artist: artists,
        album: album?['name'] as String? ?? '',
        coverUrl: coverUrl,
        playing: playing,
        canPrevious: true,
        canNext: true,
        canPlayPause: true,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  String _normalizeTitle(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  Future<void> previous() => _control('previous');
  Future<void> next() => _control('next');
  Future<void> togglePlayPause() => _control('playPause');
  Future<void> _control(String action) =>
      _channel.invokeMethod('mediaControl', {'action': action});
}
