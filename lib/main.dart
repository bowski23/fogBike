import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fog_bike/src/communication/communication_service.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'package:location/location.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController(SettingsService());
  
  await settingsController.loadSettings();

  setLocationSettings(askForGooglePlayServices: true, askForPermission: true, useGooglePlayServices: true, askForGPS: true, smallestDisplacement: 2);

  Timer(Duration(seconds: 5), () => CommunicationService().init());

  runApp(MyApp(settingsController: settingsController));
}
