import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fog_bike/src/bike_map/bike_button.dart';
import 'package:fog_bike/src/bike_map/motion_indicator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../communication/communication_service.dart';
import '../sensors/sensor_model.dart';
import '../settings/settings_view.dart';

/// The main view of the app, containing the map and the floating action button.
class BikeMapView extends StatefulWidget {
 BikeMapView({
    super.key,
  }){
  }

  static const routeName = '/';

  @override
  State<BikeMapView> createState() => _BikeMapViewState();
}

class _BikeMapViewState extends State<BikeMapView> {
  StreamSubscription<List<LocationEvent>>? _eventSubscription;

  _BikeMapViewState(){
    _eventSubscription = CommunicationService().locationEvent.listen(_onLocationEvent);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription<LocationData>? _locationSubscription;

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  Set<Marker> _markers = {};

  void _onLocationUpdate(GoogleMapController controller, LocationData? loc){
    if(loc == null) return;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(loc.latitude!, loc.longitude!),bearing: loc.bearing!, zoom: 18)));
  }


  void _onLocationEvent(List<LocationEvent> event){
    int _markerCount = 0;
    _markers = {};
    for(var elem in event){
    _markers.add(Marker(
          markerId: MarkerId("loc_$_markerCount"),
          position: LatLng(elem.latitude, elem.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(elem.dangerLevel.iconHue)));
      _markerCount++;
    } 
    setState(() {
      
    });
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
      floatingActionButton: BikeButton( onPress: () => CommunicationService().isSendingMessages = !CommunicationService().isSendingMessages,),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      
      body:FutureBuilder(future: getLocation(), initialData: LocationData(latitude: 52.51,longitude: 13.377), builder:(context, loc) {
        if(loc.data == null) return const Center(child: CircularProgressIndicator());
        return Stack(
          children: [
            GoogleMap(
            mapType: MapType.normal,
            buildingsEnabled: true,
            indoorViewEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            
            initialCameraPosition: CameraPosition(target: LatLng(loc.data!.latitude!, loc.data!.longitude!), zoom: 18),

            onMapCreated: (GoogleMapController controller) {
              controller.setMapStyle(mapStyle);
              _locationSubscription = onLocationChanged(inBackground: false).listen((event) async { _onLocationUpdate(controller, event);});
              _controller.complete(controller);
            },
      ),
      const MotionIndicator()
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