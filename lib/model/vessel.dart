import 'package:latlong/latlong.dart';
import 'package:vector_math/vector_math.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as toolkit;
import 'dart:math';

///Vessel Model
class Vessel{

  String name;
  String id;
  LatLng latLng;
  double courseOverGroundTrue;
  double speedOverGround;
  bool crashNotified = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vessel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Vessel{name: $name, id: $id, latLng: $latLng, courseOverGroundTrue: $courseOverGroundTrue, speedOverGround: $speedOverGround}';
  }

  Vessel({this.name,this.id,this.latLng,this.courseOverGroundTrue,this.speedOverGround});

  ///Costruisce un Vessel da un json
  factory Vessel.fromJson(Map<String, dynamic> json) {
    Vessel retV = Vessel();
      if(json.containsKey('uuid')){
        retV.id = json['uuid'];
      }else if(json.containsKey('mmsi')){
        retV.id = "urn:mrn:imo:mmsi:"+json['mmsi'];
      }
      retV.name = json['name']?? "";

      if(json.containsKey('navigation')){
        if(json['navigation'].containsKey('speedOverGround')){
          retV.speedOverGround = json['navigation']['speedOverGround']['value'].toDouble()??0.0;
        }else retV.speedOverGround=0.0;

        if(json['navigation'].containsKey('courseOverGroundTrue')){
          retV.courseOverGroundTrue = json['navigation']['courseOverGroundTrue']['value'].toDouble()??0.0;
        }else retV.courseOverGroundTrue=0.0;

        if(json['navigation'].containsKey('position')){
          retV.latLng = LatLng(json['navigation']['position']['value']['latitude'].toDouble(),json['navigation']['position']['value']['longitude'].toDouble());
        }

      }
      return retV;
  }


  double directionToDegrees() => this.courseOverGroundTrue * radians2Degrees; // da radianti a gradi

  ///Prevede la posizione del Vessel entro [min] minuti
  LatLng nextPosition(int min){
    double minutes = 60/min;

    ///da m/s a km/h
    double distance = (this.speedOverGround * 3.6)/minutes;
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


///Ritorna, se esiste, il Vessel con cui c'è un pericolo di collisione
  Vessel checkCollision(List<Vessel> vessels,min){
    for(Vessel vess in vessels){
      if(vess.id!=id && !vess.crashNotified) {
        double distanceBetweenPoints = toolkit.SphericalUtil
            .computeDistanceBetween(
            toolkit.LatLng(latLng.latitude, latLng.longitude),
            toolkit.LatLng(vess.latLng.latitude, vess.latLng.longitude)
        );
      if(distanceBetweenPoints < 200) {
        vess.crashNotified=true;
        return vess;
      }
      }
    }
    return null;
  }
}