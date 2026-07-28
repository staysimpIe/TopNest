import 'package:flutter/services.dart';

class WindowsShellService {
  static const _channel = MethodChannel('topnest/appbar');

  Future<void> register() => _channel.invokeMethod('register');
  Future<void> unregister() => _channel.invokeMethod('unregister');
  Future<void> reposition() => _channel.invokeMethod('reposition');

  Future<void> setEffect({
    required bool acrylic,
    required bool dark,
    required double alpha,
    int red = 245,
    int green = 245,
    int blue = 245,
  }) => _channel.invokeMethod('setEffect', {
    'acrylic': acrylic,
    'dark': dark,
    'alpha': alpha,
    'red': red,
    'green': green,
    'blue': blue,
  });

  Future<void> showTooltip(String text, double x, double y) =>
      _channel.invokeMethod('showTooltip', {'text': text, 'x': x, 'y': y});

  Future<void> hideTooltip() => _channel.invokeMethod('hideTooltip');
}
