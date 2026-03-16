import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// The three states your math logic will trigger
enum PoseFormState { neutral, good, bad }

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size absoluteImageSize;
  final PoseFormState formState;
  final bool isFrontCamera; // Crucial for mirroring the skeleton

  PosePainter(this.pose, this.absoluteImageSize, this.formState, {this.isFrontCamera = true});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dynamic Edge Color
    Color edgeColor = Colors.grey; // Default
    
    // CORRECTED: Using PoseFormState here instead of FormState
    if (formState == PoseFormState.good) edgeColor = Colors.greenAccent;
    if (formState == PoseFormState.bad) edgeColor = Colors.redAccent;

    final Paint edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = edgeColor;

    // 2. The Glow Effect (Blur filter)
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    // 3. The Solid Node Center
    final Paint nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    // 4. Coordinate Scaling (Translates ML Kit 480p to your phone's 1080p screen)
    double scaleX(double x) {
      final scaledX = x * (size.width / absoluteImageSize.width);
      // Front cameras act like mirrors; we have to flip the X axis
      return isFrontCamera ? size.width - scaledX : scaledX;
    }
    double scaleY(double y) => y * (size.height / absoluteImageSize.height);

    // Helper to draw bones between two joints
    void paintBone(PoseLandmarkType type1, PoseLandmarkType type2) {
      final joint1 = pose.landmarks[type1];
      final joint2 = pose.landmarks[type2];

      // Only draw if the AI is at least 60% sure the joint exists
      if (joint1 != null && joint2 != null && 
          joint1.likelihood > 0.6 && joint2.likelihood > 0.6) {
        canvas.drawLine(
          Offset(scaleX(joint1.x), scaleY(joint1.y)),
          Offset(scaleX(joint2.x), scaleY(joint2.y)),
          edgePaint,
        );
      }
    }

    // --- DRAW THE SKELETON (EDGES) ---
    // Torso
    paintBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    paintBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    paintBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    paintBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Arms
    paintBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    paintBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    paintBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    paintBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Legs
    paintBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    paintBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    paintBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    paintBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // --- DRAW THE NODES ---
    pose.landmarks.forEach((_, landmark) {
      if (landmark.likelihood > 0.6) {
        final offset = Offset(scaleX(landmark.x), scaleY(landmark.y));
        // Draw the blur first, then the solid core on top
        canvas.drawCircle(offset, 10.0, glowPaint); 
        canvas.drawCircle(offset, 4.0, nodePaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    // Only burn CPU cycles repainting if the user moved or the form state changed
    return oldDelegate.pose != pose || oldDelegate.formState != formState;
  }
}