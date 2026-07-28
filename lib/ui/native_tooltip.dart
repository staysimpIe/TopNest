import 'dart:async';

import 'package:flutter/material.dart';

import '../services/windows_shell_service.dart';

class NativeTooltip extends StatefulWidget {
  const NativeTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<NativeTooltip> createState() => _NativeTooltipState();
}

class _NativeTooltipState extends State<NativeTooltip> {
  final _shell = WindowsShellService();
  Timer? _timer;
  Offset _position = Offset.zero;

  void _schedule(PointerEvent event) {
    _position = event.position;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      _shell.showTooltip(widget.message, _position.dx, _position.dy + 18);
    });
  }

  void _hide([PointerEvent? _]) {
    _timer?.cancel();
    _shell.hideTooltip();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _schedule,
    onHover: (event) => _position = event.position,
    onExit: _hide,
    child: widget.child,
  );
}
