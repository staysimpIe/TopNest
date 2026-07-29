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

  test('网易云网络加载期间不推进歌词，检测到音频后开始', () async {
    var now = DateTime(2026, 7, 29, 14);
    final media = _FakeWindowsMediaService([
      const MusicState(
        available: true,
        title: '网络歌曲',
        artist: '测试歌手',
        playing: true,
        positionMs: 0,
        rawPositionMs: 0,
        audioActive: false,
        durationMs: 180000,
      ),
      const MusicState(
        available: true,
        title: '网络歌曲',
        artist: '测试歌手',
        playing: true,
        positionMs: 0,
        rawPositionMs: 0,
        audioActive: true,
        durationMs: 180000,
      ),
    ]);
    final controller = MusicController(
      media,
      _FakeLyricService(lyrics: const [LyricLine(timeMs: 1000, text: '第一句')]),
      () => now,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 3));
    expect(controller.currentLyric, isNull);

    await controller.refresh();
    now = now.add(const Duration(milliseconds: 1100));
    expect(controller.currentLyric?.text, '第一句');
  });

  test('网易云原始时间轴前进时无需音频峰值也能开始', () async {
    var now = DateTime(2026, 7, 29, 14);
    final media = _FakeWindowsMediaService([
      const MusicState(
        available: true,
        title: '网络歌曲',
        playing: true,
        rawPositionMs: 0,
        audioActive: false,
      ),
      const MusicState(
        available: true,
        title: '网络歌曲',
        playing: true,
        positionMs: 1500,
        rawPositionMs: 1500,
        audioActive: false,
      ),
    ]);
    final controller = MusicController(
      media,
      _FakeLyricService(lyrics: const [LyricLine(timeMs: 1000, text: '第一句')]),
      () => now,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 2));
    expect(controller.currentLyric, isNull);

    await controller.refresh();
    expect(controller.currentLyric?.text, '第一句');
  });

  test('网易云开始后静音不冻结歌词，暂停时冻结', () async {
    var now = DateTime(2026, 7, 29, 14);
    final media = _FakeWindowsMediaService([
      const MusicState(
        available: true,
        title: '包含静音的歌曲',
        playing: true,
        rawPositionMs: 0,
        audioActive: true,
      ),
      const MusicState(
        available: true,
        title: '包含静音的歌曲',
        playing: true,
        rawPositionMs: 0,
        audioActive: false,
      ),
      const MusicState(
        available: true,
        title: '包含静音的歌曲',
        playing: false,
        rawPositionMs: 0,
        audioActive: false,
      ),
    ]);
    final controller = MusicController(
      media,
      _FakeLyricService(
        lyrics: const [
          LyricLine(timeMs: 1000, text: '第一句'),
          LyricLine(timeMs: 3000, text: '第二句'),
        ],
      ),
      () => now,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(milliseconds: 1500));
    await controller.refresh();
    now = now.add(const Duration(milliseconds: 1700));
    expect(controller.currentLyric?.text, '第二句');

    await controller.refresh();
    now = now.add(const Duration(seconds: 5));
    expect(controller.currentLyric?.text, '第二句');
  });

  test('非网易云播放器保持原有计时行为', () async {
    var now = DateTime(2026, 7, 29, 14);
    final controller = MusicController(
      _FakeWindowsMediaService([
        const MusicState(
          available: true,
          title: '其他播放器歌曲',
          playing: true,
          positionMs: 0,
        ),
      ]),
      _FakeLyricService(lyrics: const [LyricLine(timeMs: 1000, text: '第一句')]),
      () => now,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(milliseconds: 1100));
    expect(controller.currentLyric?.text, '第一句');
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
  _FakeLyricService({this.lyrics = const []});

  final List<LyricLine> lyrics;

  @override
  Future<List<LyricLine>> load(MusicState state) async => lyrics;

  @override
  void dispose() {}
}
