

import 'dart:collection';

import 'package:fog_bike/src/communication/communication_service.dart';
import 'package:fog_bike/src/sensors/sensor_model.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:async/async.dart';

//Service that evaluates the IMU Data and generates Warning Events based on that
//It binds them to GPS Data and propagates these events to the Communication Service for further handling.
//additionally for received dangerlevel we could use a predictive position based either on a kalman filter or a simple linear extrapolation
//more sophisticatedly we could use the google maps api to bind the position to the road
class SensorService {
  static final SensorService _instance = SensorService._();
  factory SensorService() => _instance;

  late final Sensors _sensors;

  final Queue<DangerLevel> _dangerQueue = Queue<DangerLevel>();


  SensorService._(){
    _sensors = Sensors();
    StreamZip([_sensors.userAccelerometerEvents, _sensors.gyroscopeEvents]).listen((events) => _onSensorEvent(events));
    onLocationChanged().listen(_onLocationEvent);
  }

  void init() {
  }

  _onSensorEvent(List<dynamic> events){
    // ignore: unnecessary_question_mark
    UserAccelerometerEvent? accEvent = events.cast<dynamic?>().firstWhere((element) => element.runtimeType == UserAccelerometerEvent, orElse: () => null);
    // ignore: unnecessary_question_mark
    GyroscopeEvent? gyroEvent = events.cast<dynamic?>().firstWhere((element) => element.runtimeType == GyroscopeEvent, orElse: () => null);

    DangerLevel? accLevel, gyroLevel;

    if(accEvent != null){
      accLevel = DangerLevel.fromAccEvent(accEvent);
    }
    if(gyroEvent != null){
      gyroLevel = DangerLevel.fromGyroEvent(gyroEvent);
    }

    var level = max(accLevel, gyroLevel);
    if(level.numeric > DangerLevel.none.numeric){
      _dangerQueue.add(level);
    }
  }

  void _onLocationEvent(LocationData event){
    if(event.latitude == null || event.longitude == null){
      return;
    }

    DangerLevel dangerLevel = _dangerQueue.isNotEmpty ? _dangerQueue.reduce((value, element) => max(value,element)) : DangerLevel.none;
    _dangerQueue.clear();

    var locationEvent = LocationEvent(event, dangerLevel);
    CommunicationService().sendLocationEvent(locationEvent);
  }
  
}