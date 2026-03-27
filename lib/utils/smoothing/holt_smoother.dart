import '../motion_smoother.dart';

/// Holt's Double Exponential Smoothing
///
/// Advanced smoothing that tracks both level and trend (velocity).
/// Best for motion data with changing velocities.
///
/// Formula:
/// - level = alpha * current + (1-alpha) * (prev_level + prev_trend)
/// - trend = beta * (level - prev_level) + (1-beta) * prev_trend
/// - smoothed = level + trend
///
/// Parameters:
/// - alpha: Level smoothing factor (0.0 - 1.0)
///   - Lower = smoother but more lag
///   - Recommended: 0.2 - 0.4
/// - beta: Trend smoothing factor (0.0 - 1.0)
///   - Lower = less reactive to velocity changes
///   - Recommended: 0.05 - 0.15
class HoltSmoother extends MotionSmoother {
  final double alpha;
  final double beta;

  Map<String, double>? _level;
  Map<String, double>? _trend;

  HoltSmoother({required this.alpha, required this.beta})
      : assert(alpha > 0 && alpha <= 1),
        assert(beta >= 0 && beta <= 1);

  @override
  Map<String, double> smoothPoint(Map<String, double> point) {
    // First point - initialize level and trend
    if (_level == null || _trend == null) {
      _level = Map.from(point);
      _trend = point.map((key, value) => MapEntry(key, 0.0));
      return point;
    }

    final newLevel = <String, double>{};
    final newTrend = <String, double>{};

    point.forEach((key, value) {
      final prevLevel = _level![key] ?? value;
      final prevTrend = _trend![key] ?? 0.0;

      // Update level
      final levelValue = alpha * value + (1 - alpha) * (prevLevel + prevTrend);
      newLevel[key] = levelValue;

      // Update trend
      final trendValue = beta * (levelValue - prevLevel) + (1 - beta) * prevTrend;
      newTrend[key] = trendValue;
    });

    _level = newLevel;
    _trend = newTrend;

    // Return smoothed value (level + trend)
    return newLevel.map((key, value) => MapEntry(key, value + newTrend[key]!));
  }

  @override
  void reset() {
    _level = null;
    _trend = null;
  }
}
