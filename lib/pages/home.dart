import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong/latlong.dart' as lat;
import 'package:maps_toolkit/maps_toolkit.dart';
import 'package:marine/bloc/get_vessels_bloc.dart';
import 'package:marine/model/metric_system.dart';
import 'package:marine/model/vessel.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:marine/model/waypoint.dart';
import 'package:marine/pages/list_vessel.dart';
import 'package:marine/utility/dragmarker.dart';
import 'package:marine/utility/metric_choice.dart';
import 'package:marine/widget/metric_radio.dart';
import 'package:marine/widget/vessel_widget.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:easy_localization/easy_localization.dart';

// ignore: must_be_immutable
class Home extends StatefulWidget {
  List<Vessel> vessels = [];
  ///Effettuata la connessione al WebSocket, inzialmente viene richiesto di non sottoscriversi ad alcun aggiornamento.
  final channel = WebSocketChannel.connect(Uri.parse('ws://demo.signalk.org/signalk/v1/stream?subscribe=none'));

  Home({Key key}) : super(key: key);


  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Marker> _markers = [];
  int positionPrevisionMin=0;
  MapController mapController = MapController();
  bool followPosition = false;
  bool followDirection = false;
  bool checkCrash = false;
  double currentZoom = 13.0;
  bool measure = false;
  Polyline measurePolyline = Polyline(points: [lat.LatLng(0,0),lat.LatLng(0,0)]);

  ///Utile per passare il context ai widget
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ///Lista di waypoints
  List<Waypoint> waypoints = [];
  ///Lista di marker associati ai waypoints
  List <DragMarker> waypointsMarker;


  ///Lista dei marker utilizzati per il calcolo delle distanze
  List<DragMarker> distanceMarkers = [];


  ///Indice del vessel che si sta seguendo
  int selectedVesselFocus = 0;
  ///Utilizzato per calcolare le misurazioni in diversi sistemi metrici
  MetricSystem metricCalculator = MetricSystem();
  ///Serve per mantenere le informazioni sulla scelta del sistema metrico
  Metric metricChoice = Metric.meter;


  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }

  ///Utilizzato per calcolare la distanza tra i due marker,restituisce un Text con la distanza calcolata
  ///in base al sistema metrico scelto
  Text mesureDistance(){
      ///calcolo la distanza per i diversi sistemi metrici
      metricCalculator.calculate(SphericalUtil.computeDistanceBetween(
          LatLng(distanceMarkers[0].point.latitude,distanceMarkers[0].point.longitude),
          LatLng(distanceMarkers[1].point.latitude,distanceMarkers[1].point.longitude)));
      switch(metricChoice.name){
        case "meter":{
          return Text('measureDistanceBetweenPoints').tr(args: ["${metricCalculator.meter.toStringAsFixed(2)}","m"]);
        }
        case "ft":{
          return Text('measureDistanceBetweenPoints').tr(args: ["${metricCalculator.ft.toStringAsFixed(2)}","${metricChoice.name}"]);
        }
        case "yd":{
          return Text('measureDistanceBetweenPoints').tr(args: ["${metricCalculator.yd.toStringAsFixed(2)}","${metricChoice.name}"]);
        }
        case "mile":{
          return Text('measureDistanceBetweenPoints').tr(args: ["${metricCalculator.mile.toStringAsFixed(2)}","${metricChoice.name}"]);
        }
        default:{
          return Text('measureDistanceBetweenPoints').tr(args: ["${metricCalculator.meter}","m"]);
        }
      }
    }

  void generateDistanceMarkers(){

    ///Comincio a impostare la Polyline
    measurePolyline = Polyline(
        strokeWidth: 4.0,
        color: Colors.red,
        points: [mapController.center, mapController.center]);


    distanceMarkers.add(DragMarker(
      point: mapController.center,
      width: 80.0,
      height: 80.0,
      offset: Offset(0.0, -8.0),
      builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              color: Colors.white70,
              child: mesureDistance(),
            ),
            Icon(FontAwesomeIcons.mapMarkerAlt,size: 30,color: Colors.black),
          ]
      ),
      onDragStart:  (details,point) => print("Start point $point"),
      onDragEnd:    (details,point) => print("End point $point"),
      onDragUpdate: (details,point) { setState(() {
        ///ridisegno la polyline ad ogni update del marker
        List<lat.LatLng> tmp = measurePolyline.points;
        measurePolyline = Polyline(
            strokeWidth: 4.0,
            color: Colors.red,
            points: [point, tmp[1]]);
      });
      },
      onTap:        (point) { print("on tap"); },
      onLongPress:  (point) { print("on long press"); },
      feedbackBuilder: (ctx) =>  Icon(FontAwesomeIcons.mapMarkerAlt,size: 30,color: Colors.red,),
      feedbackOffset: Offset(0.0, -18.0),
      updateMapNearEdge: true,	// Experimental, move the map when marker close to edge
      nearEdgeRatio: 2.0,	// Experimental
      nearEdgeSpeed: 1.0,	// Experimental
    ));

    distanceMarkers.add(DragMarker(
      point: mapController.center,
      width: 80.0,
      height: 80.0,
      offset: Offset(0.0, -8.0),
      builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              color: Colors.white70,
              child: mesureDistance(),
            ),
            Icon(FontAwesomeIcons.mapMarkerAlt,size: 30,color: Colors.black,),
         ]
      ),
      onDragStart:  (details,point) => print("Start point $point"),
      onDragEnd:    (details,point) => print("End point $point"),
      onDragUpdate: (details,point) {
        setState(() {
          ///ridisegno la polyline ad ogni update del marker
          List<lat.LatLng> tmp = measurePolyline.points;
          measurePolyline = Polyline(
              strokeWidth: 4.0,
              color: Colors.red,
              points: [tmp[0], point]);
        });
      },
      onTap:        (point) { print("on tap"); },
      onLongPress:  (point) { print("on long press"); },
      feedbackBuilder: (ctx) =>  Icon(FontAwesomeIcons.mapMarkerAlt,size: 30,color: Colors.red,),
      feedbackOffset: Offset(0.0, -18.0),
      updateMapNearEdge: true,	// Experimental, move the map when marker close to edge
      nearEdgeRatio: 2.0,	// Experimental
      nearEdgeSpeed: 1.0,	// Experimental
    ));
  }

  ///Definisce l'aspetto di ogni [Vessel]
  Marker generateMarker(int i){
    return Marker(
        width: 70.0,
        height: 70.0,
        point: widget.vessels[i].latLng,
        builder: (ctx) => VesselWidget(vessel: widget.vessels[i], icon: i==0?'assets/images/ship_red.png': 'assets/images/ais_active.png',width: 25,height: 25));
  }

  ///Crea, per ogni [widget.vessels], il corrispettivo marker
  void createMarkers() {
    for (int i = 0; i < widget.vessels.length; i++) {
      _markers.add(generateMarker(i));
    }
  }

  ///Al caricamento del widget, scrive sul WebSocket il [msg], sottoscrivendosi ad aggiornamenti quali la posizione,
  ///velocità e direzione del [Vessel]
  @override void initState() {
    super.initState();
    var msg = {
      "context": "vessels.*",
      "subscribe": [
        {
          "path": "navigation.position",
          "period": 1000,
          "format": "delta",
          "policy": "instant",
          "minPeriod": 200
        },
        {
          "path": "navigation.speedOverGround",
          "period": 1000,
          "format": "delta",
          "policy": "instant",
          "minPeriod": 200
        },
        {
          "path": "navigation.courseOverGroundTrue",
          "period": 1000,
          "format": "delta",
          "policy": "instant",
          "minPeriod": 200
        }
      ]
    };

    var jsonString = json.encode(msg);
    widget.channel.sink.add(jsonString);
  }

  ///Chiamata in [Home.readWS], aggiorna il Marker con i nuovi dati ricevuti dal WebSocket
  void updateMarker(index){
    _markers[index]=generateMarker(index);
  }

  ///Legge il messaggio ricevuto dal WebSocket, aggiornando [widget.vessels] e il corrispettivo Marker
  void readWS(snapshot) {
    if (snapshot.hasData && !snapshot.hasError) {
      Map data = jsonDecode(snapshot.data);
      if (data.containsKey('context') && data.containsKey('updates')) {
        String id = data['context'].toString().replaceAll("vessels.", "");
        String path = data['updates'][0]['values'][0]['path'];
        int vesselToUpdateIndex = widget.vessels.indexWhere((element) =>
        element.id == id);
        if (vesselToUpdateIndex != -1) {
          Vessel vesselToUpdate = widget.vessels[vesselToUpdateIndex];
          print('modificato vessel $vesselToUpdateIndex ovvero ${vesselToUpdate
              .name}, id=${vesselToUpdate.id}');
          if (path == 'navigation.speedOverGround') {
            vesselToUpdate.speedOverGround =
                data['updates'][0]['values'][0]['value'].toDouble();
          } else if (path == 'navigation.courseOverGroundTrue') {
            vesselToUpdate.courseOverGroundTrue =
                data['updates'][0]['values'][0]['value'].toDouble();

          }else if (path == 'navigation.position') {
            lat.LatLng latLng = new lat.LatLng(
                data['updates'][0]['values'][0]['value']['latitude'].toDouble(),
                data['updates'][0]['values'][0]['value']['longitude'].toDouble()
            );
            vesselToUpdate.latLng = latLng;
          }
          vesselToUpdate.nextPosition(positionPrevisionMin);
          updateMarker(vesselToUpdateIndex);
          if(vesselToUpdateIndex==0 && (followDirection || followPosition))
            followVessel();

          if(checkCrash){
            positionPrevisionMin>0?crashDetection(positionPrevisionMin):crashDetection(20);
          }
        }
      }
    }
  }

  void crashDetection(int min){
    int slot = min~/5;
    Vessel vesselInCrash;
    int i=1;
    for(i=1;i<6 && vesselInCrash==null;i++) {
      int slice = i * slot;
      print(slice);
      if (slice != 0) {
        vesselInCrash =
            widget.vessels[selectedVesselFocus].checkCollision(
                widget.vessels, slice);
      }
    }
    if (vesselInCrash != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Crash in: ${i * slot} min with ${vesselInCrash.name}');
        final snackBar = SnackBar(content: Text('crash').tr(
            args: ['${i * slot}', '${vesselInCrash.name}']));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      });
    }
  }

  ///Se [followPosition] = true, segue il Vessel muovendo [mapController]
  ///Se [followDirection] = true, ruota la camera nella stessa direzione del Vessel
  ///Se [followDirection] = false, ruota la camera verso il Nord
  void followVessel(){
    if (followPosition)
      mapController.move(_markers[selectedVesselFocus].point, currentZoom);
    if (followDirection)
      mapController.rotate(360-widget.vessels[selectedVesselFocus].directionToDegrees());
    else
      mapController.rotate(0);

  }

  bool showNavigation=false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocConsumer<GetVesselsBloc, GetVesselsState>(
        bloc: BlocProvider.of<GetVesselsBloc>(context),
        listener: (context, state) {
          if(state is GetVesselsFailure){
            final snackBar = SnackBar(content: Text(state.message));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
          if(state is GetVesselsSucceed){
            widget.vessels = state.vessels;
            if(_markers==null || _markers.length==0){
              createMarkers();
            }
          }
        },

        builder: (context, state) {
          if(state is GetVesselsLoading) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          if(state is GetVesselsSucceed) {
            return Scaffold(
              ///definisco la chiave dello scaffold
              key: _scaffoldKey,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: StreamBuilder(
                      stream: widget.channel.stream,
                      builder: (context, snapshot) {
                        ///Aggiorna vessel ad ogni nuovo dato ricevuto dal WebSocket
                        readWS(snapshot);
                        return FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            plugins: [
                              DragMarkerPlugin(),
                            ],
                            onLongPress: (point){
                              TextEditingController _controller = TextEditingController();
                              ///TODO inserire nuovo marker con note e navigazione
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return
                                      AlertDialog(
                                          title: Text("Waypoint name"),
                                          content: SingleChildScrollView(
                                            child: TextField(
                                              controller: _controller,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                labelText: 'Note',
                                              ),
                                            )
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              child: Text('close').tr(),
                                              onPressed: () {
                                                setState(() {
                                                  waypoints.add(Waypoint(point: point,label:_controller.text,context: _scaffoldKey.currentContext));
                                                  Navigator.of(context).pop();

                                                });
                                              },
                                            ),
                                          ]
                                      );
                                  });
                            },
                            maxZoom: 16,
                            minZoom: 6,
                            center: widget.vessels[selectedVesselFocus].latLng,
                            zoom: currentZoom,
                          ),
                          layers: [
                            TileLayerOptions(
                              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: ['a', 'b', 'c'],
                            ),
                            TileLayerOptions(
                                urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png",
                                subdomains: ['a', 'b', 'c'],
                                backgroundColor: Colors.transparent
                            ),
                            MarkerLayerOptions(
                              markers: _markers,
                            ),


                            PolylineLayerOptions(
                                polylines: [Polyline(
                                    strokeWidth: 2.0,
                                    points: [
                                      widget.vessels[selectedVesselFocus].latLng,
                                      widget.vessels[selectedVesselFocus].nextPosition(
                                          positionPrevisionMin)
                                    ]
                                ), measurePolyline
                                ]
                            ),
                            DragMarkerPluginOptions(
                              markers: distanceMarkers,
                            ),
                            DragMarkerPluginOptions(
                              markers: waypoints.map<DragMarker>((row) => row.marker).toList(growable: false)

                        )
                          ],
                        );
                      },
                    ),
                  ),

                  Align(
                      alignment: Alignment.topRight,
                      child: Column(
                        children: [
                          ///Zoom in
                          IconButton(
                              onPressed: () {
                                ///aggiorna currentZoom
                                if (currentZoom != mapController.zoom)
                                  currentZoom = mapController.zoom;
                                currentZoom++;
                                mapController.move(
                                    mapController.center, currentZoom);
                              },
                              icon: Icon(
                                FontAwesomeIcons.searchPlus,
                              )
                          ),

                          ///zoom out
                          IconButton(
                              onPressed: () {
                                if (currentZoom != mapController.zoom)
                                  currentZoom = mapController.zoom;
                                currentZoom--;
                                mapController.move(
                                    mapController.center, currentZoom);
                              },
                              icon: Icon(
                                FontAwesomeIcons.searchMinus,
                              )
                          ),

                          ///Attiva/disattiva checkCrash
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  if (checkCrash) {
                                    checkCrash = false;
                                    ///Verifica se c'è una collisione lungo il tragitto
                                    for (Vessel vess in widget.vessels) {
                                      vess.crashNotified = false;
                                    }
                                  } else {
                                    checkCrash = true;
                                  }
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.exclamationTriangle,
                                color: checkCrash ? Colors.red : Colors.black,

                              )
                          ),

                          ///Mostra uno slider che setta positionPrevisionMin, utilizzato per la previsione della
                          ///prossima posizione
                          IconButton(
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return
                                        AlertDialog(
                                            title: Text('previsionInMin').tr(),
                                            content: SingleChildScrollView(
                                              child: StatefulBuilder(
                                                builder: (context, setState) =>
                                                    Slider(
                                                      value: positionPrevisionMin
                                                          .toDouble(),
                                                      onChanged: (newValue) {
                                                        setState(() {
                                                          positionPrevisionMin =
                                                              newValue.toInt();
                                                        });
                                                      },
                                                      min: 0,
                                                      max: 60,
                                                      divisions: 60,
                                                      label: positionPrevisionMin
                                                          .round().toString(),
                                                    ),
                                              ),
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: Text('close').tr(),
                                                onPressed: () {
                                                  ///Se il positionPrevisionMin cambia, resetta la flag crashNotified
                                                  ///di  tutti i vessels
                                                  for (Vessel vess in widget
                                                      .vessels) {
                                                    vess.crashNotified = false;
                                                  }
                                                  setState(() {});
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ]
                                        );
                                    });
                              },
                              icon: Icon(
                                FontAwesomeIcons.mapMarkedAlt,
                              )
                          ),

                          ///Misura la distanza tra due punti sulla mappa
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  if(measure){
                                    distanceMarkers.clear();
                                    measurePolyline = Polyline(points: [lat.LatLng(0,0),lat.LatLng(0,0)]);
                                    measure=false;
                                  }
                                  else {
                                    measure=true;
                                    generateDistanceMarkers();
                                  }
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.draftingCompass,
                                color: measure ? Colors.blue : Colors.black,

                              )
                          ),

                          ///Centra/decentra la visuale della mappa sul vessel self
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  if (currentZoom != mapController.zoom)
                                    currentZoom = mapController.zoom;
                                  if (followPosition)
                                    followPosition = false;
                                  else
                                    followPosition = true;
                                  followVessel();
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.crosshairs,
                                color: followPosition ? Colors.blue : Colors.black,
                              )
                          ),

                          ///Ruota la mappa in modo da puntare verso il NORD  o verso la direzione del vessel self
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  if (currentZoom != mapController.zoom)
                                    currentZoom = mapController.zoom;
                                  if (followDirection)
                                    followDirection = false;
                                  else
                                    followDirection = true;

                                  followVessel();
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.locationArrow,
                                color: followDirection ? Colors.blue : Colors.black,
                              )
                          ),

                          ///Push di [ListVessel]
                          IconButton(
                              onPressed: () async {

                                ///ListVessel ritorna l'indice del Vessel selezionato
                                int index = await Navigator.of(context)
                                    .push(MaterialPageRoute<int>(
                                    builder: (BuildContext context) {
                                      return BlocProvider(
                                        create: (context) =>
                                        GetVesselsBloc()
                                          ..add(GetVessels()),
                                        child: ListVessel(),
                                      );
                                    })
                                );
                                ///Se è stato scelto un vessel dalla lista, viene centrata la mappa sul vessel scelto
                                if(index!=null) {
                                  selectedVesselFocus = index;
                                  mapController.move(widget.vessels[selectedVesselFocus].latLng, currentZoom);
                                }
                              },
                              icon: Icon(
                                FontAwesomeIcons.ship,
                              )
                          ),

                          IconButton(
                              onPressed: () {
                                showDialog(context: context,
                                    builder: (context) => MetricRadio(),
                                  ///viene triggerato non appena si sceglie un valore dal dialog
                                ).then((value){
                                  setState(() {
                                    metricChoice = value;

                                  });
                                });
                              },
                              icon: Icon(
                                FontAwesomeIcons.cog,
                                color: Colors.black,
                              )
                          ),
                        ],
                      )
                  ),

                ],
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
}
