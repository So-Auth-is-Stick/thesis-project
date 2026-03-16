import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // This one is required for DeviceOrientation
class PoseExtractor {
  
  CameraController? cameraController;
  
  // Initialize the ML Kit Pose Detector (using the 'base' model for speed)
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  
  bool _isProcessing = false;

  Future<void> startCameraStream(List<CameraDescription> cameras) async {
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    
    cameraController = CameraController(frontCamera, ResolutionPreset.low);
    await cameraController!.initialize();

    cameraController!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      
      _processImage(image, frontCamera);
    });
  }

  Future<void> _processImage(CameraImage image, CameraDescription camera) async {
    try {
      // 1. The "Clever" Conversion: Let ML Kit handle the nasty byte math
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) return;

      // 2. The Extraction
      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      // 3. The Math Prep
      for (Pose pose in poses) {
        _parseCoordinates(pose);
      }
    } catch (e) {
      print("Extraction failed: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _parseCoordinates(Pose pose) {
    // ML Kit gives us an exact map of 33 joints. 
    // No more guessing array indices like in TFLite.
    
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];

    if (leftKnee != null && leftAnkle != null && leftHip != null) {
      // Notice we now have .z for depth analysis (crucial for Trunk Lean)
      double kneeX = leftKnee.x;
      double kneeZ = leftKnee.z; 
      double likelihood = leftKnee.likelihood; // Confidence score

      if (likelihood > 0.6) {
         // Push to the Python buffer:
         // {"joint": "left_knee", "x": kneeX, "y": leftKnee.y, "z": kneeZ}
      }
    }
  }
  
  // Helper: ML Kit boilerplate to convert Flutter's CameraImage to Google's InputImage
  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    // 1. Get image rotation
    // We need to figure out which way the phone is being held.
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // 2. Get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // Validate format depending on platform
    // Only supported formats: nv21/yuv420 for Android, bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21 && format != InputImageFormat.yuv_420_888) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // 3. Extract the bytes
    // Android's yuv420 splits the image into 3 planes. We have to flatten them.
    if (image.planes.isEmpty) return null;
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // 4. Build the InputImage Metadata
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    // 5. Hand it over to ML Kit
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  // Helper map for Android device orientations
  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}