import 'package:flutter/gestures.dart';
import 'package:flutter_gestures/src/double_tap_drag.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/gesture_tester.dart';

void main() {
  setUp(ensureGestureBinding);

  testGesture('recognizes double tap pan over double tap', (tester) {
    final pan = DoubleTapPanGestureRecognizer();
    final doubleTap = DoubleTapGestureRecognizer();
    addTearDown(pan.dispose);
    addTearDown(doubleTap.dispose);

    var didStartPan = false;
    pan.onStart = (_) => didStartPan = true;

    Offset? updatedDelta;
    pan.onUpdate = (details) => updatedDelta = details.delta;

    var didEndPan = false;
    pan.onEnd = (DragEndDetails details) {
      didEndPan = true;
    };

    var didDoubleTap = false;
    doubleTap.onDoubleTap = () {
      didDoubleTap = true;
    };

    // first tap

    final pointer = TestPointer(5);
    final down = pointer.down(const Offset(10.0, 10.0));
    pan.addPointer(down);
    doubleTap.addPointer(down);
    tester.closeArena(5);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer.up());
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.async.elapse(kDoubleTapMinTime);

    // second tap and drag

    final pointer2 = TestPointer(7);
    final down2 = pointer2.down(const Offset(10.0, 10.0));
    pan.addPointer(down2);
    doubleTap.addPointer(down2);
    tester.closeArena(7);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer2.move(const Offset(20.0, 20.0))); // moved 10 horizontally and 10 vertically which is 14 total
    expect(didStartPan, isFalse); // 14 < 18
    tester.route(pointer2.move(const Offset(20.0, 30.0))); // moved 10 horizontally and 20 vertically which is 22 total
    expect(didStartPan, isTrue); // 22 > 18
    didStartPan = false;
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer2.move(const Offset(20.0, 25.0)));
    expect(didStartPan, isFalse);
    expect(updatedDelta, const Offset(0.0, -5.0));
    updatedDelta = null;
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer2.up());
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isTrue);
    didEndPan = false;
    expect(didDoubleTap, isFalse);
  });

  testGesture('does not compete for double tap', (tester) {
    final pan = DoubleTapPanGestureRecognizer();
    final doubleTap = DoubleTapGestureRecognizer();
    addTearDown(pan.dispose);
    addTearDown(doubleTap.dispose);

    var didStartPan = false;
    pan.onStart = (_) => didStartPan = true;

    Offset? updatedDelta;
    pan.onUpdate = (details) => updatedDelta = details.delta;

    var didEndPan = false;
    pan.onEnd = (DragEndDetails details) {
      didEndPan = true;
    };

    var didDoubleTap = false;
    doubleTap.onDoubleTap = () {
      didDoubleTap = true;
    };

    // first tap

    final pointer = TestPointer(5);
    final down = pointer.down(const Offset(10.0, 10.0));
    pan.addPointer(down);
    doubleTap.addPointer(down);
    tester.closeArena(5);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer.up());
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.async.elapse(kDoubleTapMinTime);

    // second tap and drag

    final pointer2 = TestPointer(7);
    final down2 = pointer2.down(const Offset(10.0, 10.0));
    pan.addPointer(down2);
    doubleTap.addPointer(down2);
    tester.closeArena(7);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isFalse);

    tester.route(pointer2.up());
    expect(didStartPan, isFalse);
    expect(updatedDelta, isNull);
    expect(didEndPan, isFalse);
    expect(didDoubleTap, isTrue);
  });

  testGesture('should not recognize pan without double tap', (tester) {
    final pan = DoubleTapPanGestureRecognizer();
    addTearDown(pan.dispose);

    var didStartPan = false;
    pan.onStart = (_) {
      didStartPan = true;
    };

    Offset? updatedScrollDelta;
    pan.onUpdate = (DragUpdateDetails details) {
      updatedScrollDelta = details.delta;
    };

    var didEndPan = false;
    pan.onEnd = (DragEndDetails details) {
      didEndPan = true;
    };

    final pointer = TestPointer(5);
    final down = pointer.down(const Offset(10.0, 10.0));
    pan.addPointer(down);
    tester.closeArena(5);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);

    tester.route(down);
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);

    tester.route(pointer.move(const Offset(50.0, 50.0))); // larger than slop
    expect(didStartPan, isFalse);
    expect(updatedScrollDelta, isNull);
    expect(didEndPan, isFalse);
  });
}
