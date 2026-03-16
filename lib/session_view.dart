import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// Ensure these point to your actual file locations
import 'pose_extractor.dart';
import 'pose_painter.dart'; 

class SessionView extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SessionView({Key? key, required this.cameras}) : super(key: key);

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  late PoseExtractor _extractor;
  Pose? _currentPose;
  Size? _imageSize;
  
  // CORRECTED: Using PoseFormState
  PoseFormState _formState = PoseFormState.neutral; // Defaults to gray lines
  
  int _repCount = 0; 
  // This list will store your session data to send to the Python server
  final List<Map<String, dynamic>> _sessionDataBuffer = []; 

  @override
  void initState() {
    super.initState();
    
    // Initialize the extractor and define the callback bridge
    _extractor = PoseExtractor(
      onPoseDetected: (pose, size) {
        if (!mounted) return;
        
        setState(() {
          _currentPose = pose;
          _imageSize = size;
          
          // Execute the local tactical math
          _formState = _analyzeForm(pose);
        });
      },
    );
    
    // Fire up the camera stream
    _extractor.startCameraStream(widget.cameras);
  }

  // --- THE TACTICAL MATH (Real-time checks) ---
  // CORRECTED: Return type is now PoseFormState
  PoseFormState _analyzeForm(Pose pose) {
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Ensure all required joints are visible and confident
    if (leftKnee != null && rightKnee != null && 
        leftAnkle != null && rightAnkle != null &&
        leftKnee.likelihood > 0.6 && rightKnee.likelihood > 0.6) {
      
      // Calculate horizontal distances
      double kneeDistance = (leftKnee.x - rightKnee.x).abs();
      double ankleDistance = (leftAnkle.x - rightAnkle.x).abs();

      // Basic Valgus Check: If knees are significantly closer together than ankles
      // (This is a simplified heuristic; your team will refine the exact threshold)
      if (kneeDistance < (ankleDistance * 0.7)) {
        // Record the fault for the server
        _logFrameData(pose, "knee_valgus");
        return PoseFormState.bad; // Skeleton turns Red
      } else {
        return PoseFormState.good; // Skeleton turns Green
      }
    }
    
    return PoseFormState.neutral; // Skeleton stays Gray if not enough data
  }

  // --- THE LOGGER ---
  void _logFrameData(Pose pose, String faultType) {
    // We don't want to log 30 frames a second. 
    // In a production app, you'd throttle this to log maybe 1 frame per second of a fault.
    _sessionDataBuffer.add({
      "timestamp": DateTime.now().toIso8601String(),
      "fault": faultType,
      // You can expand this to extract specific XYZ coordinates if your server needs them
    });
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner until the camera is physically ready
    if (_extractor.cameraController == null || !_extractor.cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Standardize the aspect ratio so the painter aligns with the camera feed
    final size = MediaQuery.of(context).size;
    final scale = 1 / (_extractor.cameraController!.value.aspectRatio * size.aspectRatio);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: The Raw Camera Feed (scaled to fit screen properly)
          Transform.scale(
            scale: scale < 1 ? 1 / scale : scale,
            child: Center(
              child: CameraPreview(_extractor.cameraController!),
            ),
          ),

          // LAYER 2: The Glowing Skeleton
          if (_currentPose != null && _imageSize != null)
            CustomPaint(
              painter: PosePainter(
                _currentPose!,
                _imageSize!,
                _formState,
                // Pass true because we are using the front camera
                isFrontCamera: true, 
              ),
            ),

          // LAYER 3: The HUD (Heads Up Display)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top HUD
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Squats",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ),

                // Bottom HUD
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Rep Counter
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey, width: 4),
                          color: Colors.black54,
                        ),
                        child: Center(
                          child: Text(
                            "$_repCount",
                            style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Stop Session Button
                      FloatingActionButton(
                        backgroundColor: Colors.redAccent,
                        onPressed: () {
                          // Stop the extraction
                          _extractor.dispose();
                          
                          // TODO: Trigger the HTTP POST to send _sessionDataBuffer to the Python server
                          print("Session ended. Buffer contains ${_sessionDataBuffer.length} fault frames.");
                          
                          // Navigate to Session Report (Frame 9)
                          Navigator.pop(context); 
                        },
                        child: const Icon(Icons.stop, size: 36, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}