import '../motion_smoother.dart';

/// No smoothing - returns raw data unchanged
/// Useful for debugging and comparison
class NoSmoother extends MotionSmoother {
  @override
  Map<String, double> smoothPoint(Map<String, double> point) {
    // Return point as-is without any smoothing
    return point;
  }

  @override
  void reset() {
    // No state to reset
  }
}
