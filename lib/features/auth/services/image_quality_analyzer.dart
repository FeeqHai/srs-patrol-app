import 'dart:math' as math;

import 'package:image/image.dart' as img;

class ImageQualityResult {
  const ImageQualityResult({
    required this.isAcceptable,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.focusScore,
    required this.glareFraction,
    required this.issues,
  });

  final bool isAcceptable;
  final int width;
  final int height;
  final double aspectRatio;
  final double focusScore;
  final double glareFraction;
  final List<String> issues;
}

class ImageQualityAnalyzer {
  const ImageQualityAnalyzer();

  static const int minimumWidth = 640;
  static const int minimumHeight = 400;
  static const double minimumAspectRatio = 1.15;
  static const double maximumAspectRatio = 2.25;
  static const double minimumFocusScore = 55;
  static const double maximumGlareFraction = 0.18;

  ImageQualityResult analyzeMyKad(img.Image source) {
    final image = img.bakeOrientation(source);
    final issues = <String>[];
    final longSide = math.max(image.width, image.height);
    final shortSide = math.min(image.width, image.height);
    if (longSide < minimumWidth || shortSide < minimumHeight) {
      issues.add('Resolusi imej terlalu rendah.');
    }
    final aspectRatio = longSide / shortSide;
    if (aspectRatio < minimumAspectRatio || aspectRatio > maximumAspectRatio) {
      issues.add('Keseluruhan kad perlu kelihatan di dalam bingkai.');
    }

    final focusScore = _laplacianVariance(image);
    if (focusScore < minimumFocusScore) {
      issues.add('Imej kabur. Pegang telefon dengan stabil dan cuba semula.');
    }

    final glareFraction = _glareFraction(image);
    if (glareFraction > maximumGlareFraction) {
      issues.add('Pantulan cahaya terlalu kuat pada MyKad.');
    }

    return ImageQualityResult(
      isAcceptable: issues.isEmpty,
      width: image.width,
      height: image.height,
      aspectRatio: aspectRatio,
      focusScore: focusScore,
      glareFraction: glareFraction,
      issues: issues,
    );
  }

  double _laplacianVariance(img.Image image) {
    final resized = image.width > 640
        ? img.copyResize(
            image,
            width: 640,
            interpolation: img.Interpolation.average,
          )
        : image;
    final values = <double>[];
    for (var y = 1; y < resized.height - 1; y += 2) {
      for (var x = 1; x < resized.width - 1; x += 2) {
        final centre = _luminance(resized.getPixel(x, y));
        final laplacian =
            _luminance(resized.getPixel(x - 1, y)) +
            _luminance(resized.getPixel(x + 1, y)) +
            _luminance(resized.getPixel(x, y - 1)) +
            _luminance(resized.getPixel(x, y + 1)) -
            (4 * centre);
        values.add(laplacian);
      }
    }
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
  }

  double _glareFraction(img.Image image) {
    var sampled = 0;
    var glare = 0;
    final xStep = math.max(1, image.width ~/ 240);
    final yStep = math.max(1, image.height ~/ 160);
    for (var y = 0; y < image.height; y += yStep) {
      for (var x = 0; x < image.width; x += xStep) {
        final pixel = image.getPixel(x, y);
        sampled++;
        if (pixel.r > 245 && pixel.g > 245 && pixel.b > 245) glare++;
      }
    }
    return sampled == 0 ? 0 : glare / sampled;
  }

  double _luminance(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }
}
