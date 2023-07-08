import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';

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
    Timer.periodic(const Duration(milliseconds: 500), (timer) => _poll());
  }

  Future<dynamic> onMethodCall(MethodCall call) async{
    switch (call.method) {
      case "onResponse":
        log("dart method invoked: ${call.arguments}");
        break;
      default:
        log("Unknown method ${call.method}");
    }
  }

  void _poll() async{
    int counter = await platform.invokeMethod<int>('pollResponse') ?? -1;
    log("polled: $counter");
  }

}
