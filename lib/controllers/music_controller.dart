import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/music_state.dart';
import '../services/windows_media_service.dart';

class MusicController extends ChangeNotifier {
  MusicController(this._service);

  final WindowsMediaService _service;
  Timer? _timer;
  bool _refreshing = false;
  MusicState _state = const MusicState();

  MusicState get state => _state;

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
    _state = await _service.getState();
    _refreshing = false;
    notifyListeners();
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
    super.dispose();
  }
}
