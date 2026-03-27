/// Smoothing configuration for motion data
///
/// Change the `method` constant to switch between different smoothing algorithms.
/// All parameters are tuned for hand/pose motion tracking.

enum SmoothingMethod {
  /// No smoothing - use raw data (for debugging/comparison)
  none,

  /// Exponential Moving Average - Simple and fast
  /// Best for: Quick testing, low CPU usage
  ema,

  /// Holt's Double Exponential Smoothing - Recommended
  /// Best for: Motion tracking with velocity changes
  holt,

  /// One Euro Filter - Highest quality
  /// Best for: Maximum smoothness with responsiveness
  oneEuro,
}

class SmoothingConfig {
  // ============================================================
  // 🎯 CHANGE THIS LINE TO SWITCH SMOOTHING METHOD
  // ============================================================
  static const SmoothingMethod method = SmoothingMethod.holt;

  // ============================================================
  // Parameters for each method
  // ============================================================

  /// EMA Parameters
  /// alpha: 0.1 = very smooth but laggy, 0.5 = responsive but less smooth
  static const double emaAlpha = 0.3;

  /// Holt's Double Exponential Parameters
  /// alpha: level smoothing (0.1-0.5, lower = smoother)
  /// beta: trend smoothing (0.01-0.2, lower = less reactive to velocity changes)
  static const double holtAlpha = 0.3;
  static const double holtBeta = 0.1;

  /// One Euro Filter Parameters
  /// minCutoff: minimum cutoff frequency (0.001-1.0, lower = smoother)
  /// beta: cutoff slope (0.0-1.0, controls how much velocity affects smoothing)
  static const double oneEuroMinCutoff = 0.05;
  static const double oneEuroBeta = 0.007;

  // Private constructor to prevent instantiation
  SmoothingConfig._();
}
