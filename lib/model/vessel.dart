import 'package:latlong/latlong.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math';

class Vessel{

  String id;
  LatLng latLng;
  double directionInRadians;
  double speed;


  Vessel({this.id,this.latLng,this.directionInRadians,this.speed});

  double directionToDegrees() => this.directionInRadians * radians2Degrees; // da radianti a gradi

  LatLng nextPosition(min){
    //fra quanti minuti la previsione
    min = 60/min;

    //from m/s to km/h
    double distance = (this.speed * 3.6)/min;
    const int earthRadius = 6371;

    var lat2 = asin(sin(pi / 180 * this.latLng.latitude) * cos(distance / earthRadius) +
        cos(pi / 180 * this.latLng.latitude) * sin(distance / earthRadius) *
            cos(pi / 180 * this.directionToDegrees()));

    var lon2 = pi / 180 * this.latLng.longitude +
        atan2(sin( pi / 180 * this.directionToDegrees()) * sin(distance / earthRadius) *
            cos( pi / 180 * this.latLng.latitude ),
            cos(distance / earthRadius) - sin( pi / 180 * this.latLng.latitude) * sin(lat2));

    return LatLng(180/pi * lat2 , 180 / pi * lon2);
  }

}