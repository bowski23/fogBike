import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:fog_bike/src/sensors/sensor_service.dart';
import 'package:location/location.dart';

import '../sensors/sensor_model.dart';

//Singelton class for communication with the server
class CommunicationService {
  static const platform = MethodChannel('fog_bike.bowski.com/communication');

  static final CommunicationService _instance = CommunicationService._();
  factory CommunicationService() => _instance;

  CommunicationService._();

  final StreamController<LocationEvent> _locationEventController = StreamController<LocationEvent>();
  Stream<LocationEvent> get locationEvent => _locationEventController.stream;

  void init() async {
    dev.log("init communication service");
    platform.setMethodCallHandler(onMethodCall);
    platform.invokeMethod<void>('initZmq');
    Timer(const Duration(seconds: 1), SensorService().init);
  }

  //to-do: decide wether position should be sent back to the ui or not
  Future<dynamic> onMethodCall(MethodCall call) async{
    switch (call.method) {
      case "onResponse":
        dynamic response = call.arguments;
        var loc = LocationEvent(LocationData(latitude: response.latitude, longitude: response.longitude), DangerLevel.fromNumeric(response.level));
        dev.log("dart response: $loc");
        _locationEventController.add(loc);
        break;
      default:
        dev.log("Unknown method ${call.method}");
    }
  }

  void sendLocationEvent(LocationEvent event){
    platform.invokeMethod<void>('queueMsg', <String, dynamic>{
      'latitude':event.latitude,
      'longitude': event.longitude,
      'level': event.level
    });
  }
}
