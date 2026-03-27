import 'dart:math' as math;
import '../motion_smoother.dart';

/// One Euro Filter
///
/// Adaptive low-pass filter that adjusts smoothing based on velocity.
/// - Slow movement = heavy smoothing (reduces jitter)
/// - Fast movement = light smoothing (preserves responsiveness)
///
/// This is the gold standard for interactive motion tracking.
///
/// Parameters:
/// - minCutoff: Minimum cutoff frequency (0.001 - 1.0)
///   - Lower = smoother but more lag
///   - Recommended: 0.01 - 0.1
/// - beta: Cutoff slope (0.0 - 1.0)
///   - Controls how much velocity affects smoothing
///   - Recommended: 0.001 - 0.01
class OneEuroSmoother extends MotionSmoother {
  final double minCutoff;
  final double beta;
  final double dcutoff = 1.0; // Cutoff for derivative

  Map<String, _LowPassFilter>? _filters;
  Map<String, _LowPassFilter>? _derivativeFilters;
  DateTime? _lastTime;

  OneEuroSmoother({required this.minCutoff, required this.beta})
      : assert(minCutoff > 0),
        assert(beta >= 0);

  @override
  Map<String, double> smoothPoint(Map<String, double> point) {
    final now = DateTime.now();

    // First point - initialize filters
    if (_filters == null) {
      _filters = {};
      _derivativeFilters = {};
      point.forEach((key, value) {
        _filters![key] = _LowPassFilter(alpha: _alphaFromCutoff(minCutoff, 1.0));
        _derivativeFilters![key] = _LowPassFilter(alpha: _alphaFromCutoff(dcutoff, 1.0));
        _filters![key]!.filter(value);
      });
      _lastTime = now;
      return point;
    }

    // Calculate time delta
    final dt = now.difference(_lastTime!).inMicroseconds / 1000000.0;
    _lastTime = now;

    final smoothed = <String, double>{};

    point.forEach((key, value) {
      // Calculate derivative (velocity)
      final derivative = (_filters![key]!.lastValue != null)
          ? (value - _filters![key]!.lastValue!) / dt
          : 0.0;

      // Smooth the derivative
      final smoothedDerivative = _derivativeFilters![key]!.filter(derivative);

      // Calculate adaptive cutoff based on velocity
      final cutoff = minCutoff + beta * smoothedDerivative.abs();

      // Apply filter with adaptive alpha
      final alpha = _alphaFromCutoff(cutoff, dt);
      _filters![key]!.alpha = alpha;
      smoothed[key] = _filters![key]!.filter(value);
    });

    return smoothed;
  }

  @override
  void reset() {
    _filters = null;
    _derivativeFilters = null;
    _lastTime = null;
  }

  /// Calculate alpha from cutoff frequency
  double _alphaFromCutoff(double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }
}

/// Simple low-pass filter helper class
class _LowPassFilter {
  double alpha;
  double? lastValue;

  _LowPassFilter({required this.alpha});

  double filter(double value) {
    if (lastValue == null) {
      lastValue = value;
      return value;
    }
    final filtered = alpha * value + (1 - alpha) * lastValue!;
    lastValue = filtered;
    return filtered;
  }
}
