import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'session_view.dart'; 

Future<void> main() async {
  // Lock the initialization so we can access hardware before the UI paints
  WidgetsFlutterBinding.ensureInitialized();
  
  // Fetch the list of physical cameras on the device
  final cameras = await availableCameras();
  
  // Ignite the app and pass the hardware data down
  runApp(ThesisApp(cameras: cameras));
}

class ThesisApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const ThesisApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Tracker',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      // Bypass the counter app and load your 3D skeleton view immediately
      home: SessionView(cameras: cameras), 
    );
  }
}