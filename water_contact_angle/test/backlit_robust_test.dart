import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:water_contact_angle/image_processor.dart';

/// Regression test for the "same-tone drop + substrate with internal specular
/// reflection" failure (superhydrophobic drop on a dark matte stage).
///
/// Before the backlit-robust fallback, image 19.jpg measured ~10 deg; the true
/// angle is ~150-160 deg. Put 19.jpg at <root>/regression/19.jpg (or adjust the
/// path below). The test is skipped if the image is not present, so it will not
/// break CI on machines that do not have it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Adjust to your checkout root (matches the convention in the other tests).
  const root = '/Users/uday/btp/water_contact_angle';

  test('superhydrophobic low-contrast drop measures ~150-160 deg', () async {
    final candidates = [
      File('$root/regression/19.jpg'),
      File('$root/19.jpg'),
    ];
    final f = candidates.firstWhere(
      (c) => c.existsSync(),
      orElse: () => File(''),
    );
    if (!f.existsSync()) {
      // ignore: avoid_print
      print('SKIP: 19.jpg not found in ${candidates.map((c) => c.path)}');
      return;
    }

    final r = await ImageProcessor.processImage(f);
    final measured = (r['angle_numeric'] as num?)?.toDouble();

    expect(measured, isNotNull);
    expect(measured!.isFinite, isTrue,
        reason: 'pipeline returned a non-finite angle: $measured');
    expect(
      measured,
      inInclusiveRange(140.0, 170.0),
      reason: 'expected ~150-160 deg for this superhydrophobic drop, '
          'got ${measured.toStringAsFixed(1)} deg '
          '(backlit-robust fallback likely did not engage)',
    );
  });
}
