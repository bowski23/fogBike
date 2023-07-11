import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
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

  final StreamController<List<LocationEvent>> _locationEventController = StreamController<List<LocationEvent>>();
  Stream<List<LocationEvent>> get locationEvent => _locationEventController.stream;

  ValueNotifier<bool> isConnectionLost = ValueNotifier<bool>(false);

  bool isSendingMessages = false;

  void init() async {
    dev.log("init communication service");
    platform.setMethodCallHandler(onMethodCall);
    platform.invokeMethod<void>('initZmq');
    Timer(const Duration(seconds: 1), SensorService().init);
  }

  Future<dynamic> onMethodCall(MethodCall call) async{
    switch (call.method) {
      case "onResponse":
        Map<String,dynamic> response;
        response = const JsonDecoder().convert(call.arguments as String);
        List<dynamic> list = response["coordinates"];
        List<LocationEvent> locs = [];
        for(var elem in list){
          var loc = LocationEvent(LocationData(latitude: elem["latitude"], longitude: elem["longitude"]), DangerLevel.fromNumeric(elem["level"]));
          locs.add(loc);
        }
        dev.log("dart response: $locs");
        _locationEventController.add(locs);
        break;
      case "connectionLost":
        dev.log("connection lost");
        isConnectionLost.value = true;
        break;
      default:
        dev.log("Unknown method ${call.method}");
    }
  }

  void sendLocationEvent(LocationEvent event){
    if(isSendingMessages){
      platform.invokeMethod<void>('queueMsg', <String, dynamic>{
        'latitude': event.latitude,
        'longitude': event.longitude,
        'level': event.level
      });
    }
  }
}
