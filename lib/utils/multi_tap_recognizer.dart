import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MultiTapListener extends StatefulWidget {
  final Widget child;
  final void Function() onDoubleTap;

  const MultiTapListener({required this.onDoubleTap, required this.child});

  @override
  State<MultiTapListener> createState() => _MultiTapListenerState();
}

class _MultiTapListenerState extends State<MultiTapListener> {
  int _tapCount = 0;
  Timer? _resetTimer;
  Offset? _lastPosition;
  DateTime? _pointerDownTime;

  // A tap held longer than this is considered a long press
  static const _longPressThreshold = Duration(milliseconds: 300);

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownTime = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent event) {
    final downTime = _pointerDownTime;
    _pointerDownTime = null;

    // If finger was held too long, it's a long press — reset and ignore
    if (downTime == null ||
        DateTime.now().difference(downTime) > _longPressThreshold) {
      _tapCount = 0;
      _resetTimer?.cancel();
      return;
    }

    // Reset if taps are too far apart spatially
    if (_lastPosition != null &&
        (event.position - _lastPosition!).distance > kDoubleTapSlop) {
      _tapCount = 0;
    }
    _lastPosition = event.position;
    _tapCount++;

    if (_tapCount >= 2) {
      _tapCount = 0;
      _resetTimer?.cancel();
      widget.onDoubleTap();
    } else {
      _resetTimer?.cancel();
      // Reset if second tap doesn't arrive in time
      _resetTimer = Timer(kDoubleTapTimeout, () {
        _tapCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }
}
