import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:fog_bike/src/sensors/sensor_service.dart';

import '../sensors/sensor_model.dart';

//Singelton class for communication with the server
class CommunicationService {
  static const platform = MethodChannel('fog_bike.bowski.com/communication');

  static final CommunicationService _instance = CommunicationService._();
  factory CommunicationService() => _instance;

  CommunicationService._();

  void init() async {
    log("init communication service");
    platform.setMethodCallHandler(onMethodCall);
    platform.invokeMethod<void>('initZmq');
    Timer(const Duration(seconds: 1), SensorService().init);
  }

  //to-do: decide wether position should be sent back to the ui or not
  Future<dynamic> onMethodCall(MethodCall call) async{
    switch (call.method) {
      case "onResponse":
        int level = call.arguments;
        DangerLevel dangerLevel = DangerLevel.fromNumeric(level);
        log("dart response: ${dangerLevel.name}");

        break;
      default:
        log("Unknown method ${call.method}");
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
