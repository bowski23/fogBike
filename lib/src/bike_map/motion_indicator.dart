import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionIndicator extends StatefulWidget {
  const MotionIndicator({ Key? key }) : super(key: key);

  @override
  _MotionIndicatorState createState() => _MotionIndicatorState();
}

class _MotionIndicatorState extends State<MotionIndicator> {
  UserAccelerometerEvent _userAccelerometerEvent = UserAccelerometerEvent(0, 0, 0);
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerEventSubscription;
  UserAccelerometerEvent _animationEvent = UserAccelerometerEvent(0, 0, 0);

  _MotionIndicatorState(){
    // the user accelerometer filters out the gravitational acceleration, so basically any extreme amplitude of acceleration could trigger a warning event
    // to figure out what extreme amplitude means, we should conduct some tests
    var sensors = Sensors();
    _userAccelerometerEventSubscription = sensors.userAccelerometerEvents.listen((event) {
      _userAccelerometerEvent = event;
    });

    // the animation event is a low-pass filtered version of the user accelerometer event, it is used to smooth out the animation and uses a periodic timer to decouple the animation from the user accelerometer event
    double decayFactor = 0.7;
    Timer.periodic(const Duration(milliseconds: 17), (timer) { 
      setState(() {
        _animationEvent = UserAccelerometerEvent(_userAccelerometerEvent.x * decayFactor + _animationEvent.x * (1-decayFactor), _userAccelerometerEvent.y * decayFactor + _animationEvent.y * (1-decayFactor), _userAccelerometerEvent.z * decayFactor + _animationEvent.z * (1-decayFactor));
    }); });
  }

  @override
  void dispose() {
    _userAccelerometerEventSubscription?.cancel();
    super.dispose();
  }

  //maybe we should indicate different directions of acceleration with different colors, but for now we'll just use the same color for all directions
  @override
  Widget build(BuildContext context) {
    return Row( mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(6.0),
          child: SizedBox(width: 64, height: 64, child: Stack( alignment: Alignment.topCenter, fit: StackFit.expand,
            children: [
              const Center(child:  Text("x", style: TextStyle(fontSize: 30, color: Colors.black54))),
              RotatedBox(quarterTurns: 2, child: CircularProgressIndicator(value: _animationEvent.x.abs()/10, backgroundColor: Colors.black54, color: Colors.green, strokeWidth: 8, semanticsLabel: "x acceleration", semanticsValue: _userAccelerometerEvent.x.toString(),)),
            ],
          )),
        ),
        Padding(
          padding: const EdgeInsets.all(6.0),
          child: SizedBox(width: 64, height: 64, child: Stack( alignment: Alignment.topCenter, fit: StackFit.expand,
            children: [
              const Center(child:  Text("y", style: TextStyle(fontSize: 30, color: Colors.black54))),
              RotatedBox(quarterTurns: 2, child: CircularProgressIndicator(value: _animationEvent.y.abs()/10, backgroundColor: Colors.black54, color: Colors.green, strokeWidth: 8, semanticsLabel: "y acceleration", semanticsValue: _userAccelerometerEvent.y.toString(),)),
            ],
          )),
        ),
        Padding(
          padding: const EdgeInsets.all(6.0),
          child: SizedBox(width: 64, height: 64, child: Stack( alignment: Alignment.topCenter, fit: StackFit.expand,
            children: [
              const Center(child:  Text("z", style: TextStyle(fontSize: 30, color: Colors.black54))),
              RotatedBox(quarterTurns: 2, child: CircularProgressIndicator(value: _animationEvent.z.abs()/10, backgroundColor: Colors.black54, color: Colors.green, strokeWidth: 8, semanticsLabel: "z acceleration", semanticsValue: _userAccelerometerEvent.z.toString(),)),
            ],
          )),
        ),
        ],
    );
  }
}