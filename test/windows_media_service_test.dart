import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/models/music_state.dart';
import 'package:topnest/services/windows_media_service.dart';

void main() {
  test('使用 SMTC 元数据匹配当前歌曲，不读取旧的 isPlayedOnce 条目', () {
    final service = WindowsMediaService();
    final items = <Map>[
      {
        'isPlayedOnce': true,
        'track': {
          'id': 'old-song',
          'name': 'Losing Game',
          'duration': 175846,
          'artists': [
            {'name': 'Maximillian'},
          ],
          'album': {'name': 'Too Young'},
        },
      },
      {
        'isPlayedOnce': false,
        'track': {
          'id': 'current-song',
          'name': 'Sukidayo -Hyakkai No Koukai- (English Version)',
          'duration': 210000,
          'artists': [
            {'name': "Che'Nelle"},
          ],
          'album': {'name': 'Too Young'},
        },
      },
    ];

    final result = service.matchNeteaseTrack(
      items,
      const MusicState(
        title: 'Sukidayo -Hyakkai No Koukai- (English Version)',
        artist: "Che'Nelle",
        album: 'Too Young',
        durationMs: 210500,
      ),
    );

    expect((result?['track'] as Map)['id'], 'current-song');
  });

  test('SMTC 元数据不匹配时不返回任意缓存歌曲', () {
    final service = WindowsMediaService();
    final result = service.matchNeteaseTrack([
      {
        'isPlayedOnce': true,
        'track': {
          'id': 'old-song',
          'name': 'Losing Game',
          'artists': [
            {'name': 'Maximillian'},
          ],
        },
      },
    ], const MusicState(title: '完全不同的歌曲', artist: '另一位歌手'));

    expect(result, isNull);
  });
}
