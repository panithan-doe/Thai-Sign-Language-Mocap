import '../motion_smoother.dart';

/// Exponential Moving Average (EMA) Smoother
///
/// Simple and fast smoothing algorithm.
/// Formula: smoothed = alpha * current + (1-alpha) * previous
///
/// Parameters:
/// - alpha: Smoothing factor (0.0 - 1.0)
///   - Lower = smoother but more lag
///   - Higher = more responsive but less smooth
///   - Recommended: 0.2 - 0.4 for motion tracking
class EMASmoother extends MotionSmoother {
  final double alpha;
  Map<String, double>? _previousPoint;

  EMASmoother({required this.alpha}) : assert(alpha > 0 && alpha <= 1);

  @override
  Map<String, double> smoothPoint(Map<String, double> point) {
    // First point - no previous data
    if (_previousPoint == null) {
      _previousPoint = Map.from(point);
      return point;
    }

    // Apply EMA to each coordinate
    final smoothed = <String, double>{};
    point.forEach((key, value) {
      final prevValue = _previousPoint![key] ?? value;
      smoothed[key] = alpha * value + (1 - alpha) * prevValue;
    });

    _previousPoint = smoothed;
    return smoothed;
  }

  @override
  void reset() {
    _previousPoint = null;
  }
}
