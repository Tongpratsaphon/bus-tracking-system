import 'package:flutter/material.dart';

class LocationProvider extends ChangeNotifier {
  double latitude = 0.0;
  double longitude = 0.0;

  void updateLocation(double lat, double lng) {
    latitude = lat;
    longitude = lng;
    notifyListeners(); // แจ้งเตือน UI ให้เปลี่ยนแปลง
  }
}
