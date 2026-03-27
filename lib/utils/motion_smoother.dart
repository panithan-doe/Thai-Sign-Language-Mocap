import 'smoothing_config.dart';
import 'smoothing/ema_smoother.dart';
import 'smoothing/holt_smoother.dart';
import 'smoothing/one_euro_smoother.dart';
import 'smoothing/no_smoother.dart';

/// Base class for motion smoothing algorithms
abstract class MotionSmoother {
  /// Smooth a single landmark point (x, y, z)
  Map<String, double> smoothPoint(Map<String, double> point);

  /// Reset internal state (call when switching to a new motion clip)
  void reset();

  /// Factory method to create smoother based on config
  static MotionSmoother create() {
    switch (SmoothingConfig.method) {
      case SmoothingMethod.none:
        return NoSmoother();
      case SmoothingMethod.ema:
        return EMASmoother(alpha: SmoothingConfig.emaAlpha);
      case SmoothingMethod.holt:
        return HoltSmoother(
          alpha: SmoothingConfig.holtAlpha,
          beta: SmoothingConfig.holtBeta,
        );
      case SmoothingMethod.oneEuro:
        return OneEuroSmoother(
          minCutoff: SmoothingConfig.oneEuroMinCutoff,
          beta: SmoothingConfig.oneEuroBeta,
        );
    }
  }
}
