import 'dart:typed_data';

class MusicState {
  const MusicState({
    this.available = false,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.cover,
    this.coverUrl,
    this.playing = false,
    this.canPrevious = false,
    this.canNext = false,
    this.canPlayPause = false,
    this.trackId,
    this.positionMs = 0,
    this.rawPositionMs = 0,
    this.audioActive,
    this.durationMs = 0,
    this.error,
  });

  final bool available;
  final String title;
  final String artist;
  final String album;
  final Uint8List? cover;
  final String? coverUrl;
  final bool playing;
  final bool canPrevious;
  final bool canNext;
  final bool canPlayPause;
  final String? trackId;
  final int positionMs;
  final int rawPositionMs;
  final bool? audioActive;
  final int durationMs;
  final String? error;

  MusicState copyWith({bool? playing, int? positionMs}) => MusicState(
    available: available,
    title: title,
    artist: artist,
    album: album,
    cover: cover,
    coverUrl: coverUrl,
    playing: playing ?? this.playing,
    canPrevious: canPrevious,
    canNext: canNext,
    canPlayPause: canPlayPause,
    trackId: trackId,
    positionMs: positionMs ?? this.positionMs,
    rawPositionMs: rawPositionMs,
    audioActive: audioActive,
    durationMs: durationMs,
    error: error,
  );

  factory MusicState.fromMap(Map<Object?, Object?> value) {
    final rawCover = value['cover'];
    return MusicState(
      available: value['available'] == true,
      title: value['title'] as String? ?? '',
      artist: value['artist'] as String? ?? '',
      album: value['album'] as String? ?? '',
      cover: rawCover is Uint8List ? rawCover : null,
      coverUrl: value['coverUrl'] as String?,
      playing: value['playing'] == true,
      canPrevious: value['canPrevious'] == true,
      canNext: value['canNext'] == true,
      canPlayPause: value['canPlayPause'] == true,
      trackId: value['trackId']?.toString(),
      positionMs: (value['positionMs'] as num?)?.toInt() ?? 0,
      rawPositionMs: (value['rawPositionMs'] as num?)?.toInt() ?? 0,
      audioActive: value['audioActive'] is bool
          ? value['audioActive'] as bool
          : null,
      durationMs: (value['durationMs'] as num?)?.toInt() ?? 0,
      error: value['error'] as String?,
    );
  }
}

class LyricLine {
  const LyricLine({required this.timeMs, required this.text});

  final int timeMs;
  final String text;
}
