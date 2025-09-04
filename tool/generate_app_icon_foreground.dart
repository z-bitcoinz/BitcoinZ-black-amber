import 'dart:io';
import 'package:image/image.dart' as img;

// Generates a padded Android adaptive foreground icon from assets/app_icon/app_icon.png
// Output: assets/app_icon/app_icon_foreground.png
// - Canvas: 1024x1024 transparent
// - Scales the source to ~70% of canvas size, centered
// - Preserves aspect ratio
void main() {
  final inputPath = 'assets/app_icon/app_icon.png';
  final outputPath = 'assets/app_icon/app_icon_foreground.png';

  if (!File(inputPath).existsSync()) {
    stderr.writeln('Input not found: $inputPath');
    exit(1);
  }

  final bytes = File(inputPath).readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Failed to decode input image');
    exit(1);
  }

  // Ensure 1024x1024 working image
  final int canvasSize = 1024;
  img.Image srcFit;
  if (src.width != canvasSize || src.height != canvasSize) {
    // Fit within 1024 preserving aspect ratio
    final double scaleW = canvasSize / src.width;
    final double scaleH = canvasSize / src.height;
    final double scale = scaleW < scaleH ? scaleW : scaleH;
    final int newW = (src.width * scale).round();
    final int newH = (src.height * scale).round();
    srcFit = img.copyResize(src, width: newW, height: newH, interpolation: img.Interpolation.cubic);
  } else {
    srcFit = src;
  }

  // Create transparent canvas
  final canvas = img.Image(width: canvasSize, height: canvasSize);
  // Fill with transparent pixels
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Target logo size ~70% of canvas
  const double targetRatio = 0.70;
  final int targetW = (canvasSize * targetRatio).round();
  final int targetH = (canvasSize * targetRatio).round();

  // Scale srcFit to fit within targetW x targetH, preserving aspect
  final double scaleW2 = targetW / srcFit.width;
  final double scaleH2 = targetH / srcFit.height;
  final double scale2 = scaleW2 < scaleH2 ? scaleW2 : scaleH2;
  final int logoW = (srcFit.width * scale2).round();
  final int logoH = (srcFit.height * scale2).round();
  final img.Image logo = img.copyResize(srcFit, width: logoW, height: logoH, interpolation: img.Interpolation.cubic);

  // Center it
  final int dx = ((canvasSize - logoW) / 2).round();
  final int dy = ((canvasSize - logoH) / 2).round();
  // Draw logo onto canvas
  img.compositeImage(canvas, logo, dstX: dx, dstY: dy);

  // Encode PNG
  final outBytes = img.encodePng(canvas);
  File(outputPath).writeAsBytesSync(outBytes);
  stdout.writeln('Generated foreground: $outputPath (logo ${logoW}x${logoH} on ${canvasSize}x${canvasSize})');
}

