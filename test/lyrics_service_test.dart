import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/models/music_state.dart';
import 'package:topnest/services/lyrics_service.dart';

void main() {
  test('解析 LRC 时间轴并按时间排序', () {
    final service = LyricsService();
    addTearDown(service.dispose);

    final lines = service.parse('''
[00:12.50]第二句
[00:01.005][00:03.10]第一句
[ar:歌手]
''');

    expect(lines.map((line) => line.timeMs), [1005, 3100, 12500]);
    expect(lines.map((line) => line.text), ['第一句', '第一句', '第二句']);
  });

  test('LRCLIB 根据歌名歌手和时长选择正确的同步歌词', () {
    final service = LyricsService();
    addTearDown(service.dispose);
    const state = MusicState(
      available: true,
      title: '同名歌曲',
      artist: '正确歌手',
      album: '正确专辑',
      durationMs: 183000,
    );

    final result = service.selectBestSyncedLyrics([
      {
        'trackName': '同名歌曲',
        'artistName': '其他歌手',
        'albumName': '其他专辑',
        'duration': 260,
        'syncedLyrics': '[00:01.00]错误歌词',
      },
      {
        'trackName': '同名歌曲',
        'artistName': '正确歌手',
        'albumName': '正确专辑',
        'duration': 184,
        'syncedLyrics': '[00:01.00]正确歌词',
      },
    ], state);

    expect(result, '[00:01.00]正确歌词');
  });
}
