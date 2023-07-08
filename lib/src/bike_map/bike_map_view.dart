import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fog_bike/src/bike_map/bike_button.dart';
import 'package:fog_bike/src/bike_map/motion_indicator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../settings/settings_view.dart';

/// The main view of the app, containing the map and the floating action button.
class BikeMapView extends StatelessWidget {
 BikeMapView({
    super.key,
  });

  //statless widgets don't have a dispose lifecycle but i'll leave this here as a reminder to think over the widget type, but for now it seems like it doesn't need state, as only child widgets change themselves and this widget stays the same
  void dispose() {
    _locationSubscription?.cancel();
  }

  static const routeName = '/';
  StreamSubscription<LocationData>? _locationSubscription;

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  void _onLocationUpdate(GoogleMapController controller, LocationData? loc){
    if(loc == null) return;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(loc.latitude!, loc.longitude!),bearing: loc.bearing!, zoom: 18)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      floatingActionButton: const BikeButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      
      body:FutureBuilder(future: getLocation(), initialData: LocationData(latitude: 0,longitude: 0), builder:(context, loc) {
        if(loc.data == null) return const Center(child: CircularProgressIndicator());
        return Stack(
          children: [
            GoogleMap(
            mapType: MapType.normal,
            buildingsEnabled: true,
            indoorViewEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            
            initialCameraPosition: CameraPosition(target: LatLng(loc.data!.latitude!, loc.data!.longitude!), zoom: 18),

            onMapCreated: (GoogleMapController controller) {
              controller.setMapStyle(mapStyle);
              _locationSubscription = onLocationChanged(inBackground: false).listen((event) async { _onLocationUpdate(controller, event);});
              _controller.complete(controller);
            },
      ),
      MotionIndicator()
          ],
        );
      },) 
    );
  }
}

const mapStyle = r'''[
  {
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative",
    "stylers": [
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.neighborhood",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "landscape",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#a3a3a3"
      },
      {
        "visibility": "on"
      },
      {
        "weight": 1.5
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "transit.station.rail",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  }
]'''; 