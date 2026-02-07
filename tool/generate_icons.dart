// Run this script to generate placeholder app icons
// dart run tool/generate_icons.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('Generating placeholder app icons...');

  // Colors
  final bgColor = img.ColorRgba8(26, 26, 46, 255); // #1a1a2e
  final accentColor = img.ColorRgba8(0, 212, 170, 255); // #00d4aa
  final white = img.ColorRgba8(255, 255, 255, 255);

  // Generate app_icon.png (1024x1024)
  final appIcon = _generateIcon(1024, bgColor, accentColor, white);
  await File('assets/icons/app_icon.png').writeAsBytes(img.encodePng(appIcon));
  print('✓ Created assets/icons/app_icon.png');

  // Generate app_icon_foreground.png (1024x1024, transparent background)
  final foreground = _generateForeground(1024, accentColor, white);
  await File('assets/icons/app_icon_foreground.png')
      .writeAsBytes(img.encodePng(foreground));
  print('✓ Created assets/icons/app_icon_foreground.png');

  // Generate splash_logo.png (512x512)
  final splash = _generateIcon(512, bgColor, accentColor, white);
  await File('assets/icons/splash_logo.png')
      .writeAsBytes(img.encodePng(splash));
  print('✓ Created assets/icons/splash_logo.png');

  print('\nAll icons generated! Now run:');
  print('  flutter pub run flutter_launcher_icons');
  print('  flutter pub run flutter_native_splash:create');
}

img.Image _generateIcon(
    int size, img.Color bgColor, img.Color accentColor, img.Color textColor) {
  final image = img.Image(width: size, height: size);

  // Fill background
  img.fill(image, color: bgColor);

  // Draw circular background
  final center = size ~/ 2;
  final radius = (size * 0.45).toInt();
  img.fillCircle(image,
      x: center, y: center, radius: radius, color: accentColor);

  // Draw inner circle (darker)
  final innerRadius = (size * 0.35).toInt();
  img.fillCircle(image,
      x: center, y: center, radius: innerRadius, color: bgColor);

  // Draw navigation pin shape (simple triangle pointing up)
  final pinTop = (size * 0.15).toInt();
  final pinBottom = (size * 0.55).toInt();
  final pinWidth = (size * 0.15).toInt();

  // Navigation indicator (triangle)
  _drawFilledTriangle(
    image,
    center, pinTop, // top point
    center - pinWidth, pinBottom, // bottom left
    center + pinWidth, pinBottom, // bottom right
    accentColor,
  );

  // Draw "SN" text approximation (simplified)
  // S shape
  final textY = (size * 0.6).toInt();
  final textSize = (size * 0.08).toInt();

  // Simple S
  img.fillCircle(image,
      x: center - textSize * 2, y: textY, radius: textSize, color: accentColor);
  img.fillCircle(image,
      x: center - textSize * 2,
      y: textY + textSize * 2,
      radius: textSize,
      color: accentColor);

  // Simple N
  img.fillRect(image,
      x1: center + textSize,
      y1: textY - textSize,
      x2: center + textSize + textSize ~/ 2,
      y2: textY + textSize * 3,
      color: accentColor);
  img.fillRect(image,
      x1: center + textSize * 3,
      y1: textY - textSize,
      x2: center + textSize * 3 + textSize ~/ 2,
      y2: textY + textSize * 3,
      color: accentColor);

  return image;
}

img.Image _generateForeground(
    int size, img.Color accentColor, img.Color textColor) {
  final image = img.Image(width: size, height: size);

  // Transparent background
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  final center = size ~/ 2;

  // Draw navigation pin
  final pinTop = (size * 0.2).toInt();
  final pinBottom = (size * 0.6).toInt();
  final pinWidth = (size * 0.12).toInt();

  _drawFilledTriangle(
    image,
    center,
    pinTop,
    center - pinWidth,
    pinBottom,
    center + pinWidth,
    pinBottom,
    accentColor,
  );

  // Circle at bottom of pin
  final circleY = (size * 0.65).toInt();
  img.fillCircle(image,
      x: center, y: circleY, radius: (size * 0.12).toInt(), color: accentColor);

  return image;
}

void _drawFilledTriangle(img.Image image, int x1, int y1, int x2, int y2,
    int x3, int y3, img.Color color) {
  // Simple scanline fill for triangle
  final minY = [y1, y2, y3].reduce((a, b) => a < b ? a : b);
  final maxY = [y1, y2, y3].reduce((a, b) => a > b ? a : b);

  for (int y = minY; y <= maxY; y++) {
    final intersections = <int>[];

    // Check intersection with each edge
    _addEdgeIntersection(intersections, x1, y1, x2, y2, y);
    _addEdgeIntersection(intersections, x2, y2, x3, y3, y);
    _addEdgeIntersection(intersections, x3, y3, x1, y1, y);

    if (intersections.length >= 2) {
      intersections.sort();
      for (int x = intersections.first; x <= intersections.last; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

void _addEdgeIntersection(
    List<int> intersections, int x1, int y1, int x2, int y2, int y) {
  if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
    final x = x1 + (y - y1) * (x2 - x1) ~/ (y2 - y1);
    intersections.add(x);
  }
}
