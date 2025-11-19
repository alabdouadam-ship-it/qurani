import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create a simple Islamic-themed icon
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Green background
  final paint = Paint()..color = const Color(0xFF2E7D32);
  canvas.drawRect(Rect.fromLTWH(0, 0, 1024, 1024), paint);
  
  // White circle for content area
  paint.color = Colors.white;
  canvas.drawCircle(Offset(512, 512), 400, paint);
  
  // Green circle border
  paint.color = const Color(0xFF2E7D32);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 20;
  canvas.drawCircle(Offset(512, 512), 400, paint);
  
  // Arabic text "ق" (Qaf for Quran)
  final textPainter = TextPainter(
    text: TextSpan(
      text: 'ق',
      style: TextStyle(
        fontSize: 300,
        color: const Color(0xFF2E7D32),
        fontFamily: 'Cairo',
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.rtl,
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(512 - textPainter.width/2, 512 - textPainter.height/2));
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(1024, 1024);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  if (byteData != null) {
    final file = File('assets/icon/icon.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    print('Icon created successfully!');
  }
}

