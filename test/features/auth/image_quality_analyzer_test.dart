import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:srs_app/features/auth/services/image_quality_analyzer.dart';

void main() {
  const analyzer = ImageQualityAnalyzer();

  test('accepts a sharp landscape capture within the MyKad framing range', () {
    final image = _checkerboard(width: 800, height: 500);

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isTrue);
    expect(result.issues, isEmpty);
    expect(result.width, 800);
    expect(result.height, 500);
    expect(result.aspectRatio, closeTo(1.6, 0.001));
    expect(
      result.focusScore,
      greaterThanOrEqualTo(ImageQualityAnalyzer.minimumFocusScore),
    );
    expect(
      result.glareFraction,
      lessThanOrEqualTo(ImageQualityAnalyzer.maximumGlareFraction),
    );
  });

  test('accepts a sharp portrait capture within the MyKad framing range', () {
    final image = _checkerboard(width: 500, height: 800);

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isTrue);
    expect(result.issues, isEmpty);
    expect(result.width, 500);
    expect(result.height, 800);
    expect(result.aspectRatio, closeTo(1.6, 0.001));
  });

  test('rejects low-resolution captures regardless of orientation', () {
    final image = img.Image(width: 200, height: 320);

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isFalse);
    expect(result.issues, contains('Resolusi imej terlalu rendah.'));
  });

  test('rejects captures with a cropped or implausible normalized aspect', () {
    final image = _checkerboard(width: 1000, height: 400);

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isFalse);
    expect(
      result.issues,
      contains('Keseluruhan kad perlu kelihatan di dalam bingkai.'),
    );
  });

  test('rejects a blurry landscape capture', () {
    final image = img.Image(width: 800, height: 500);
    img.fill(image, color: img.ColorRgb8(120, 120, 120));

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isFalse);
    expect(result.focusScore, lessThan(ImageQualityAnalyzer.minimumFocusScore));
    expect(
      result.issues,
      contains('Imej kabur. Pegang telefon dengan stabil dan cuba semula.'),
    );
  });

  test('reports excessive glare for an overexposed image', () {
    final image = img.Image(width: 800, height: 500);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    final result = analyzer.analyzeMyKad(image);

    expect(result.isAcceptable, isFalse);
    expect(
      result.glareFraction,
      greaterThan(ImageQualityAnalyzer.maximumGlareFraction),
    );
    expect(result.issues, contains('Pantulan cahaya terlalu kuat pada MyKad.'));
  });
}

img.Image _checkerboard({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final light = ((x ~/ 12) + (y ~/ 12)).isEven;
      image.setPixel(
        x,
        y,
        light ? img.ColorRgb8(205, 210, 215) : img.ColorRgb8(35, 45, 55),
      );
    }
  }
  return image;
}
