import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// All code in this file is adapted form Flutter's DoubleTapGestureDetector and OneSequenceGestureRecognizer

/// CountdownZoned tracks whether the specified duration has elapsed since
/// creation, honoring [Zone].
class _CountdownZoned {
  _CountdownZoned({required Duration duration}) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

/// TapTracker helps track individual tap sequences as part of a
/// larger gesture.
class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
  })  : pointer = event.pointer,
        _initialGlobalPosition = event.position,
        initialButtons = event.buttons,
        _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4? transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance!.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance!.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

/// Recognizes when the user has tapped the screen at the same location twice in
/// quick succession and delegates any further handling of that second tap to
/// a subclass
///
/// [DoubleTapAndGestureRecognizer] competes on pointer events of [kPrimaryButton]
/// only when it has a non-null callback. If it has no callbacks, it is a no-op.
///
abstract class DoubleTapAndGestureRecognizer extends GestureRecognizer {
  /// Create a gesture recognizer for double taps.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.kind}
  DoubleTapAndGestureRecognizer({
    Object? debugOwner,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner, kind: kind);

  // Implementation notes:
  //
  // The double tap recognizer can be in one of four states. There's no
  // explicit enum for the states, because they are already captured by
  // the state of existing fields. Specifically:
  //
  // 1. Waiting on first tap: In this state, the _trackers list is empty, and
  //    _firstTap is null.
  // 2. First tap in progress: In this state, the _trackers list contains all
  //    the states for taps that have begun but not completed. This list can
  //    have more than one entry if two pointers begin to tap.
  // 3. Waiting on second tap: In this state, one of the in-progress taps has
  //    completed successfully. The _trackers list is again empty, and
  //    _firstTap records the successful tap.
  // 4. Second pointer in progress: _firstTap is non-null. If the subclass accepts
  //    this pointer while in this state, the double tap state is reset.
  // 5. The subclass is handling tracking the second (and any subsequent pointers)
  // 6. When the subclass stop tracking the last pointer, the state is reset
  //    completely.
  //
  // There are various other scenarios that cause the state to reset:
  //
  // - All in-progress taps are rejected (by time, distance, pointer cancel, etc)
  // - The long timer between taps expires
  // - The gesture arena decides we have been rejected wholesale

  /// A pointer has contacted the screen with a primary button at the same
  /// location twice in quick succession, which might be the start of a double
  /// tap.
  ///
  /// This triggers immediately after the down event of the second tap.
  ///
  /// If this recognizer doesn't win the arena, [onDoubleTapCancel] is called
  /// next. Otherwise, [onDoubleTap] is called next.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [TapDownDetails], which is passed as an argument to this callback.
  ///  * [GestureDetector.onDoubleTapDown], which exposes this callback.
  GestureTapDownCallback? onDoubleTapDown;

  /// A pointer that previously triggered [onDoubleTapDown] will not end up
  /// causing a double tap.
  ///
  /// This triggers once the gesture loses the arena if [onDoubleTapDown] has
  /// previously been triggered.
  ///
  /// If this recognizer wins the arena, [onDoubleTap] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [GestureDetector.onDoubleTapCancel], which exposes this callback.
  GestureTapCancelCallback? onDoubleTapCancel;

  Timer? _doubleTapTimer;
  _TapTracker? _firstTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};
  bool _handlingSecondPointer = false;

  final Map<int, GestureArenaEntry> _secondEntries = <int, GestureArenaEntry>{};
  final Set<int> _trackedSecondPointers = HashSet<int>();

  @protected
  bool get hasCallbacks;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onDoubleTapDown == null && onDoubleTapCancel == null && !hasCallbacks) {
            return false;
          }
          break;
        default:
          return false;
      }
      return super.isPointerAllowed(event);
    } else if (_secondEntries.isEmpty) {
      if (event.buttons != _firstTap!.initialButtons) {
        return false;
      }
      return super.isPointerAllowed(event) && isSecondPointerAllowed(event);
    } else {
      return super.isPointerAllowed(event) && isSecondPointerAllowed(event);
    }
  }

  @protected
  bool isSecondPointerAllowed(PointerEvent event) {
    return true;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        _trackTap(event);
      } else {
        if (onDoubleTapDown != null) {
          final TapDownDetails details = TapDownDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            kind: getKindForPointer(event.pointer),
          );
          invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
        }
        _handlingSecondPointer = true;
        addSecondAllowedPointer(event);
      }
    } else if (_handlingSecondPointer) {
      _handlingSecondPointer = true;
      addSecondAllowedPointer(event);
    } else {
      _trackTap(event);
    }
  }

  /// Called when a pointer event is routed to this recognizer.
  @protected
  void handleEvent(PointerEvent event);

  @protected
  void addSecondAllowedPointer(PointerDownEvent event);

  GestureArenaEntry _addPointerToArena(int pointer) {
    return GestureBinding.instance!.gestureArena.add(pointer, this);
  }

  @protected
  void startTrackingPointer(int pointer, [Matrix4? transform]) {
    GestureBinding.instance!.pointerRouter.addRoute(pointer, handleEvent, transform);
    _trackedSecondPointers.add(pointer);
    assert(!_secondEntries.containsValue(pointer));
    _secondEntries[pointer] = _addPointerToArena(pointer);
  }

  /// Stops events related to the given pointer ID from being routed to this recognizer.
  ///
  /// If this function reduces the number of tracked pointers to zero, it will
  /// call [didStopTrackingLastPointer] synchronously.
  ///
  /// Use [startTrackingPointer] to add the routes in the first place.
  @protected
  void stopTrackingPointer(int pointer) {
    if (_trackedSecondPointers.contains(pointer)) {
      GestureBinding.instance!.pointerRouter.removeRoute(pointer, handleEvent);
      _trackedSecondPointers.remove(pointer);
      if (_trackedSecondPointers.isEmpty) didStopTrackingLastPointer(pointer);
    }
  }

  // tracks a "first" tap (several may be in progress)
  void _trackTap(PointerDownEvent event) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance!.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      assert(_firstTap == null);
      _registerFirstTap(tracker);
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) _reject(tracker);
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  /// Called when the number of pointers this recognizer is tracking changes from one to zero.
  ///
  /// The given pointer ID is the ID of the last pointer this recognizer was
  /// tracking.
  @mustCallSuper
  @protected
  void didStopTrackingLastPointer(int pointer) {
    _secondEntries.clear();
    _handlingSecondPointer = false;
    _reset();
  }

  /// Resolves this recognizer's participation in each gesture arena with the
  /// given disposition.
  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    final List<GestureArenaEntry> localEntries = List<GestureArenaEntry>.from(_secondEntries.values);
    _secondEntries.clear();
    for (final GestureArenaEntry entry in localEntries) entry.resolve(disposition);
  }

  /// Resolves this recognizer's participation in the given gesture arena with
  /// the given disposition.
  @protected
  @mustCallSuper
  void resolvePointer(int pointer, GestureDisposition disposition) {
    final GestureArenaEntry? entry = _secondEntries[pointer];
    if (entry != null) {
      _secondEntries.remove(pointer);
      entry.resolve(disposition);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (_handlingSecondPointer) {
      if (_secondEntries.containsKey(pointer)) {
        _acceptedSecondPointer();
      }
      acceptSecondGesture(pointer);
    }
  }

  @mustCallSuper
  @override
  void rejectGesture(int pointer) {
    if (_handlingSecondPointer) {
      rejectSecondGesture(pointer);
    } else {
      _TapTracker? tracker = _trackers[pointer];
      // If tracker isn't in the list, check if this is the first tap tracker
      if (tracker == null && _firstTap != null && _firstTap!.pointer == pointer) tracker = _firstTap;
      // If tracker is still null, we rejected ourselves already
      if (tracker != null) _reject(tracker);
    }
  }

  @protected
  void acceptSecondGesture(int pointer) {}

  @protected
  void rejectSecondGesture(int pointer) {}

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null) {
      if (tracker == _firstTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) _reset();
      }
    }
  }

  @mustCallSuper
  @override
  void dispose() {
    resolve(GestureDisposition.rejected);
    for (final int pointer in _trackedSecondPointers)
      GestureBinding.instance!.pointerRouter.removeRoute(pointer, handleEvent);
    _trackedSecondPointers.clear();
    assert(_secondEntries.isEmpty);
    _reset();
    super.dispose();
  }

  void _reset() {
    _stopDoubleTapTimer();
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) _checkCancel();
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance!.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
    GestureBinding.instance!.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _acceptedSecondPointer() {
    if (_firstTap != null) {
      _firstTap!.entry.resolve(GestureDisposition.accepted);
      _reset();
    }
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startDoubleTapTimer() {
    _doubleTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopDoubleTapTimer() {
    if (_doubleTapTimer != null) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
    }
  }

  void _checkCancel() {
    if (onDoubleTapCancel != null) invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
  }
}
