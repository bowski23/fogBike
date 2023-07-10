
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';

  //the thresholds represent the lower bounds for each danger category in ascending order, eg. low, mid, high
  //these thresholds have been experimentally determined (solely in one test run), however they may differ by user and device
  //for now these are sufficient for a proof of concept and detect bumps, sudden obstacle avoidance, as well as very sudden braking
  //a more sophisticated approach would be suitable, but is out of scope for this project
  //a low-pass filtered version of acceleration could determine massive prolonged acceleration/deceleration which is not detected by the thresholds
  //these prolonged events would be a good indicator for normal braking or riding downhill. speed could also be used for this purpose  
enum DangerLevel{
  none(0.0, 0.0, 0, BitmapDescriptor.hueBlue),
  low(45, 2.5, 1, BitmapDescriptor.hueYellow),
  medium(60, 3.0, 2, BitmapDescriptor.hueOrange),
  high(75, 3.5, 3, BitmapDescriptor.hueRed);

  const DangerLevel(this.lowerBoundAcc, this.lowerBoundGyro, this.numeric, this.iconHue);

  final double lowerBoundAcc;
  final double lowerBoundGyro;
  final int numeric;
  final double iconHue;

  static DangerLevel fromNumeric(int numeric) {
    switch (numeric) {
      case 0:
        return none;
      case 1:
        return low;
      case 2:
        return medium;
      case 3:
        return high;
      default:
        return none;
    }
  }

  static DangerLevel fromAcc(double acc) {
    if (acc < low.lowerBoundAcc) {
      return none;
    } else if (acc < medium.lowerBoundAcc) {
      return low;
    } else if (acc < high.lowerBoundAcc) {
      return medium;
    } else {
      return high;
    }
  }

  static DangerLevel fromGyro(double gyro) {
    if (gyro < low.lowerBoundGyro) {
      return none;
    } else if (gyro < medium.lowerBoundGyro) {
      return low;
    } else if (gyro < high.lowerBoundGyro) {
      return medium;
    } else {
      return high;
    }
  }

  static DangerLevel fromAccEvent(UserAccelerometerEvent event){
    var abs = sqrt(pow(event.x,2) + pow(event.y,2) + pow(event.z,2));
    return fromAcc(abs);
  }

  static DangerLevel fromGyroEvent(GyroscopeEvent event){
    var abs = sqrt(pow(event.x,2) + pow(event.y,2) + pow(event.z,2));
    return fromGyro(abs);
  }
}

DangerLevel max(DangerLevel? a, DangerLevel? b){
  if(a == null || b == null) {
    return a ?? b ?? DangerLevel.none;
  }

  if(a.numeric > b.numeric){
    return a;
  }else{
    return b;
  }
}

class LocationEvent {
  LocationEvent(this.locationData, this.dangerLevel);

  final LocationData locationData;
  final DangerLevel dangerLevel;

  double get latitude => locationData.latitude!;
  double get longitude => locationData.longitude!;
  int get level => dangerLevel.numeric;

  @override
  String toString() {
    
    return "LocationEvent: lat: $latitude, long: $longitude, level: $level";
  }
}
