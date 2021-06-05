import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gestures/flutter_gestures.dart';

void main() {
  runApp(MaterialApp(home: DoubleTapDragExample()));
}

class DoubleTapDragExample extends StatefulWidget {
  const DoubleTapDragExample({Key? key}) : super(key: key);

  @override
  _DoubleTapDragExampleState createState() => _DoubleTapDragExampleState();
}

class _DoubleTapDragExampleState extends State<DoubleTapDragExample> {
  Size _size = Size(300, 300);

  Offset _offset = Offset(200, 200);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffffaa00),
      body: Stack(
        children: [
          Positioned(
            left: _offset.dx,
            top: _offset.dy,
            width: _size.width,
            height: _size.height,
            child: Container(
              width: 300,
              height: 300,
              child: GestureDetector(
                onPanDown: (_) => print('1 onPanDown'),
                onPanStart: (_) => print('1 onPanStart'),
                onPanUpdate: (details) {
                  setState(() {
                    _offset += details.delta;
                  });
                },
                onPanEnd: (_) => print('1 onPanEnd'),
                onPanCancel: () => print('1 onPanCancel'),
                onDoubleTap: () => print('Double tap'),
                child: DoubleTapDragGestureDetector(
                  onDoubleTapDown: (_) => print('onDoubleTapDown'),
                  onDoubleTapCancel: () => print('onDoubleTapCancel'),
                  onPanDown: (_) => print('onPanDown'),
                  onPanStart: (_) => print('onPanStart'),
                  onPanUpdate: (details) {
                    setState(() {
                      _size += details.delta;
                    });
                  },
                  onPanEnd: (_) => print('onPanEnd'),
                  onPanCancel: () => print('onPanCancel'),
                  child: Container(
                    width: 300,
                    height: 300,
                    color: Color(0xff88cc55),
                    alignment: Alignment.center,
                    child: Text('Drag to reposition\nDouble-tap drag to resize', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
