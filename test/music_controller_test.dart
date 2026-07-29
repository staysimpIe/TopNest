import 'package:flutter_test/flutter_test.dart';
import 'package:topnest/controllers/music_controller.dart';
import 'package:topnest/models/music_state.dart';
import 'package:topnest/services/lyrics_service.dart';
import 'package:topnest/services/windows_media_service.dart';

void main() {
  test('同一首歌暂停和恢复时忽略 SMTC 异常归零', () async {
    final media = _FakeWindowsMediaService([
      const MusicState(
        available: true,
        title: '测试歌曲',
        artist: '测试歌手',
        playing: true,
        positionMs: 120000,
        durationMs: 240000,
      ),
      const MusicState(
        available: true,
        title: '测试歌曲',
        artist: '测试歌手',
        playing: false,
        positionMs: 0,
        durationMs: 240000,
      ),
      const MusicState(
        available: true,
        title: '测试歌曲',
        artist: '测试歌手',
        playing: true,
        positionMs: 0,
        durationMs: 240000,
      ),
    ]);
    final controller = MusicController(media, _FakeLyricService());
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.refresh();
    expect(controller.state.positionMs, greaterThanOrEqualTo(120000));

    await controller.refresh();
    expect(controller.state.positionMs, greaterThanOrEqualTo(120000));
  });
}

class _FakeWindowsMediaService extends WindowsMediaService {
  _FakeWindowsMediaService(this.states);

  final List<MusicState> states;
  var index = 0;

  @override
  Future<MusicState> getState() async => states[index++];
}

class _FakeLyricService extends LyricsService {
  @override
  Future<List<LyricLine>> load(MusicState state) async => const [];

  @override
  void dispose() {}
}
