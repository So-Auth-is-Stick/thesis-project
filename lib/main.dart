import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'session_view.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize cameras before the app starts
  final cameras = await availableCameras();
  
  runApp(ThesisApp(cameras: cameras));
}

class ThesisApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const ThesisApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSU Thesis - Pose Tracker',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: SessionView(cameras: cameras), 
    );
  }
}