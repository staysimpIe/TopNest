import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/music_state.dart';
import '../services/lyrics_service.dart';
import '../services/windows_media_service.dart';

class MusicController extends ChangeNotifier {
  MusicController(
    this._service, [
    LyricsService? lyricService,
    DateTime Function()? now,
  ]) : _lyricService = lyricService ?? LyricsService(),
       _now = now ?? DateTime.now;

  final WindowsMediaService _service;
  final LyricsService _lyricService;
  final DateTime Function() _now;
  Timer? _timer;
  Timer? _lyricRetryTimer;
  bool _refreshing = false;
  MusicState _state = const MusicState();
  List<LyricLine> _lyrics = const [];
  String? _lyricsTrackKey;
  String? _lyricError;
  bool _loadingLyrics = false;
  late DateTime _stateUpdatedAt = _now();
  bool _playbackStarted = true;
  int _initialRawPositionMs = 0;

  MusicState get state => _state;
  String? get lyricError => _lyricError;
  bool get loadingLyrics => _loadingLyrics;

  LyricLine? get currentLyric {
    final index = _currentLyricIndex;
    return index < 0 ? null : _lyrics[index];
  }

  LyricLine? get nextLyric {
    final index = _currentLyricIndex + 1;
    return index <= 0 || index >= _lyrics.length ? null : _lyrics[index];
  }

  int get _currentLyricIndex {
    if (_lyrics.isEmpty) return -1;
    final elapsed = _canAdvance(_state)
        ? _now().difference(_stateUpdatedAt).inMilliseconds
        : 0;
    final position = _state.positionMs + elapsed;
    var result = -1;
    for (var index = 0; index < _lyrics.length; index++) {
      if (_lyrics[index].timeMs > position) break;
      result = index;
    }
    return result;
  }

  void start() {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    var nextState = await _service.getState();
    final now = _now();
    final sameTrack =
        _trackIdentity(_state) != null &&
        _trackIdentity(_state) == _trackIdentity(nextState);
    final wasAdvancing = _canAdvance(_state);
    _updatePlaybackStart(nextState, sameTrack: sameTrack);
    if (sameTrack) {
      final elapsed = wasAdvancing
          ? now.difference(_stateUpdatedAt).inMilliseconds
          : 0;
      final estimatedPosition = _state.positionMs + elapsed;
      final returnedToZero =
          nextState.positionMs == 0 && estimatedPosition > 2000;
      final playingPositionIsStale =
          wasAdvancing &&
          nextState.playing &&
          estimatedPosition > nextState.positionMs;
      if (returnedToZero || playingPositionIsStale) {
        final position = nextState.durationMs > 0
            ? (estimatedPosition > nextState.durationMs
                  ? nextState.durationMs
                  : estimatedPosition)
            : estimatedPosition;
        nextState = nextState.copyWith(positionMs: position);
      }
    }
    _state = nextState;
    _stateUpdatedAt = now;
    _refreshing = false;
    notifyListeners();

    final trackKey = _lyricsKey(nextState);
    if (trackKey != null && trackKey != _lyricsTrackKey) {
      unawaited(_loadLyrics(trackKey, nextState));
    } else if (trackKey == null && _lyricsTrackKey != null) {
      _lyricRetryTimer?.cancel();
      _lyricsTrackKey = null;
      _lyrics = const [];
      _lyricError = null;
    }
  }

  bool _canAdvance(MusicState state) =>
      state.playing && (state.audioActive == null || _playbackStarted);

  void _updatePlaybackStart(MusicState nextState, {required bool sameTrack}) {
    if (nextState.audioActive == null) {
      _playbackStarted = true;
      _initialRawPositionMs = nextState.rawPositionMs;
      return;
    }
    if (!sameTrack) {
      _initialRawPositionMs = nextState.rawPositionMs;
      _playbackStarted =
          nextState.audioActive == true || nextState.rawPositionMs > 0;
      return;
    }
    if (!_playbackStarted &&
        (nextState.audioActive == true ||
            nextState.rawPositionMs != _initialRawPositionMs)) {
      _playbackStarted = true;
    }
  }

  String? _trackIdentity(MusicState state) {
    if (!state.available || state.title.trim().isEmpty) return null;
    return '${state.title.trim().toLowerCase()}|'
        '${state.artist.trim().toLowerCase()}|'
        '${state.album.trim().toLowerCase()}';
  }

  String? _lyricsKey(MusicState state) {
    final identity = _trackIdentity(state);
    if (identity == null) return null;
    final trackId = state.trackId;
    return trackId == null || trackId.isEmpty ? identity : '$identity|$trackId';
  }

  Future<void> _loadLyrics(String trackKey, MusicState state) async {
    _lyricRetryTimer?.cancel();
    final changedTrack = _lyricsTrackKey != trackKey;
    _lyricsTrackKey = trackKey;
    if (changedTrack) _lyrics = const [];
    _lyricError = null;
    _loadingLyrics = true;
    notifyListeners();
    try {
      final lyrics = await _lyricService.load(state);
      if (_lyricsTrackKey != trackKey) return;
      _lyrics = lyrics;
      if (lyrics.isEmpty) _lyricError = '当前歌曲暂无同步歌词';
    } catch (error, stackTrace) {
      debugPrint('歌词读取失败：$error\n$stackTrace');
      if (_lyricsTrackKey == trackKey) {
        _lyricError = '歌词读取失败，正在重试';
        _lyricRetryTimer = Timer(const Duration(seconds: 10), () {
          if (_lyricsTrackKey == trackKey && !_loadingLyrics) {
            unawaited(_loadLyrics(trackKey, state));
          }
        });
      }
    } finally {
      if (_lyricsTrackKey == trackKey) {
        _loadingLyrics = false;
        notifyListeners();
      }
    }
  }

  Future<void> previous() => _run(_service.previous);
  Future<void> next() => _run(_service.next);

  Future<void> togglePlayPause() async {
    _state = _state.copyWith(playing: !_state.playing);
    notifyListeners();
    await _run(_service.togglePlayPause);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } finally {
      await refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lyricRetryTimer?.cancel();
    _lyricService.dispose();
    super.dispose();
  }
}
