import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:marine/connection/vessel_repo.dart';
import 'package:marine/model/vessel.dart';

import 'home.dart';

class Loading extends StatefulWidget {
  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {


  void loadFirstPosition() async{
    VesselRepo request = VesselRepo();

    List<Vessel> vessels = await request.createVessels();
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
        builder: (context) => Home(vessels: vessels)
        )
    );
  }

  @override void initState() {
    super.initState();
    loadFirstPosition();
  }

  //grafica
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blue[100],
        body: Center(
            child : SpinKitRotatingCircle(
              color: Colors.white,
              size: 50.0,
            )
        )
    );
  }
}
