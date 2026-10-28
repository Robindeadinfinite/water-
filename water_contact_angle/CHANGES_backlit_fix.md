# Fix: measure low-contrast / specular superhydrophobic drops (e.g. 19.jpg)

## What was wrong
On images where the drop body and the substrate are the **same darkness** (no
brightness edge at the contact line) and a **specular reflection** cuts through
the drop, the silhouette stage merged drop + substrate + background into one
dark blob. The baseline that feeds `baseline_detector` then landed near the top
of the drop, and the fit collapsed to a near-flat angle (~10 deg instead of the
true ~150-160 deg).

Validated on 19.jpg: the new path recovers **156 deg** (circle fit,
center (777,618), R=92).

## The change is additive and gated
It only activates when the normal result is **physically impossible** (baseline
above the drop's widest row) or when the normal path is **not confident**. It
cannot fire on the drops that already measure correctly, so the PFOTES
ground-truth accuracy (~1.5 deg MAE) should be unchanged.

---

## 1) `lib/processing/silhouette_extractor.dart`  (DONE — use the provided file)
Replace your file with the provided `silhouette_extractor.dart`. It adds:
- `extractBacklitRobust(...)` — a contrast-independent extractor:
  1. baseline = modal row of the per-column bright->dark transition (the
     substrate top wins the vote; the drop's own top edge is a minority),
  2. drop profile = per-row leftmost/rightmost foreground pixel above the
     baseline, grown upward with row-to-row connectivity (interior specular
     highlights are ignored because only the extreme edges per row are taken).
- a plausibility guard at the end of `extract()` that returns the robust result
  when the detected baseline sits clearly above the widest contour row.

## 2) `lib/image_processor.dart`  (APPLY THIS SMALL EDIT)
Second safety net, for when the normal path returns null / low confidence.

Find (around line 1708):

```dart
      final silhouette = SilhouetteExtractor.extract(grayValues, width, height,
          inverted: inverted, roi: roi);
      final bool useSilhouette =
          silhouette != null && silhouette.confidence >= 0.55;
```

Replace with:

```dart
      var silhouette = SilhouetteExtractor.extract(grayValues, width, height,
          inverted: inverted, roi: roi);
      // Same-tone drop+substrate / internal specular reflection: the normal path
      // bails out or is not confident. Try the contrast-independent backlit path
      // before falling back to the legacy edge pipeline.
      if (silhouette == null || silhouette.confidence < 0.55) {
        final robust = SilhouetteExtractor.extractBacklitRobust(
            grayValues, width, height,
            inverted: inverted, roi: roi);
        if (robust != null && robust.confidence >= 0.55) {
          silhouette = robust;
          _log('🪟 Using backlit-robust fallback extractor');
        }
      }
      final bool useSilhouette =
          silhouette != null && silhouette.confidence >= 0.55;
```

(The only functional change is `final silhouette` -> `var silhouette` plus the
inserted block.)

## 3) `test/backlit_robust_test.dart`  (ADD)
Use the provided test. Put the failing capture at
`<root>/regression/19.jpg` and set `root` to your checkout path (same convention
as the other tests). It asserts the angle lands in 140-170 deg and skips if the
image is absent.

---

## How to verify (must do — I could not compile/run Dart here)
```bash
flutter analyze
flutter test test/pfotes_ground_truth_test.dart   # MAE must stay ~1.5 deg (no regression)
flutter test test/backlit_robust_test.dart         # 19.jpg must land ~150-160 deg
```

## Honest caveats
- The algorithm is validated in Python on 19.jpg; the Dart is a faithful
  translation but has **not been compiled or run** in this environment.
- The guard assumes the current failure places the baseline near the drop top
  (consistent with a ~10 deg output). If your build instead fails further
  downstream while keeping a correct baseline, hook #2 is what catches it.
- This is a software mitigation. The real root cause is acquisition: a drop and
  substrate of equal tone plus a specular hotspot. A diffuse uniform backlight
  that makes the background bright and kills the reflection will fix this class
  of image at the source and is far more reliable for metrology.
