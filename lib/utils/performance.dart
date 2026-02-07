import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Performance mode for the app
enum PerformanceMode {
  high, // Full effects, longer animations
  medium, // Reduced blur, moderate animations
  low, // Minimal effects, fastest animations
}

/// Global performance settings manager
class PerformanceConfig {
  static PerformanceConfig? _instance;
  static PerformanceConfig get instance => _instance ??= PerformanceConfig._();

  PerformanceConfig._() {
    _detectPerformanceMode();
  }

  PerformanceMode _mode = PerformanceMode.medium;
  PerformanceMode get mode => _mode;

  bool _isLowEndDevice = false;
  bool get isLowEndDevice => _isLowEndDevice;

  /// Detect device performance capabilities
  void _detectPerformanceMode() {
    // Check frame rate capability
    final refreshRate =
        SchedulerBinding.instance.platformDispatcher.displays.first.refreshRate;

    // Check if running on web (usually needs optimization)
    if (kIsWeb) {
      _mode = PerformanceMode.medium;
      return;
    }

    // Check platform and make educated guess
    if (Platform.isAndroid) {
      // Check for low memory indicators via refresh rate (older devices often 60hz)
      if (refreshRate <= 60) {
        _isLowEndDevice = true;
        _mode = PerformanceMode.low;
      } else if (refreshRate <= 90) {
        _mode = PerformanceMode.medium;
      } else {
        _mode = PerformanceMode.high;
      }
    } else if (Platform.isIOS) {
      // iOS devices are generally well optimized
      if (refreshRate <= 60) {
        _mode = PerformanceMode.medium;
      } else {
        _mode = PerformanceMode.high;
      }
    } else {
      _mode = PerformanceMode.high;
    }
  }

  /// Manually set performance mode
  void setMode(PerformanceMode mode) {
    _mode = mode;
  }

  /// Animation duration multiplier based on performance mode
  double get animationMultiplier {
    switch (_mode) {
      case PerformanceMode.high:
        return 1.0;
      case PerformanceMode.medium:
        return 0.8;
      case PerformanceMode.low:
        return 0.5;
    }
  }

  /// Blur sigma based on performance mode
  double get blurSigma {
    switch (_mode) {
      case PerformanceMode.high:
        return 10.0;
      case PerformanceMode.medium:
        return 5.0;
      case PerformanceMode.low:
        return 0.0; // No blur for low-end
    }
  }

  /// Should use backdrop filter
  bool get useBackdropFilter {
    return _mode != PerformanceMode.low;
  }

  /// Should use complex shadows
  bool get useComplexShadows {
    return _mode == PerformanceMode.high;
  }

  /// Should use gradient backgrounds
  bool get useGradients {
    return _mode != PerformanceMode.low;
  }

  /// Max stagger delay for list animations
  int get maxStaggerDelayMs {
    switch (_mode) {
      case PerformanceMode.high:
        return 50;
      case PerformanceMode.medium:
        return 30;
      case PerformanceMode.low:
        return 0; // No stagger for low-end
    }
  }
}

/// Adaptive duration that respects performance settings
Duration adaptiveDuration(Duration base) {
  final multiplier = PerformanceConfig.instance.animationMultiplier;
  return Duration(milliseconds: (base.inMilliseconds * multiplier).round());
}

/// Adaptive blur filter
ImageFilter? adaptiveBlur({double sigma = 10}) {
  final config = PerformanceConfig.instance;
  if (!config.useBackdropFilter) return null;
  final adaptedSigma = sigma * (config.blurSigma / 10);
  if (adaptedSigma < 1) return null;
  return ImageFilter.blur(sigmaX: adaptedSigma, sigmaY: adaptedSigma);
}

/// Optimized backdrop filter wrapper
class OptimizedBlur extends StatelessWidget {
  final Widget child;
  final double sigma;
  final Color? fallbackColor;

  const OptimizedBlur({
    super.key,
    required this.child,
    this.sigma = 10,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final config = PerformanceConfig.instance;

    if (!config.useBackdropFilter) {
      // Use solid color fallback for low-end devices
      return Container(
        color: fallbackColor ?? Colors.black.withValues(alpha:0.7),
        child: child,
      );
    }

    final adaptedSigma = sigma * (config.blurSigma / 10);
    if (adaptedSigma < 1) {
      return Container(
        color: fallbackColor ?? Colors.black.withValues(alpha:0.5),
        child: child,
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: adaptedSigma, sigmaY: adaptedSigma),
      child: child,
    );
  }
}

/// Optimized shadow that adapts to device performance
List<BoxShadow> optimizedShadow({
  Color color = Colors.black,
  double opacity = 0.2,
  double blurRadius = 10,
  Offset offset = const Offset(0, 4),
  double spreadRadius = 0,
}) {
  final config = PerformanceConfig.instance;

  if (!config.useComplexShadows) {
    // Simplified shadow for medium/low performance
    return [
      BoxShadow(
        color: color.withValues(alpha:opacity * 0.5),
        blurRadius: blurRadius * 0.5,
        offset: offset,
      ),
    ];
  }

  return [
    BoxShadow(
      color: color.withValues(alpha:opacity),
      blurRadius: blurRadius,
      offset: offset,
      spreadRadius: spreadRadius,
    ),
  ];
}

/// Optimized glow shadow
List<BoxShadow> optimizedGlow(Color color, {double opacity = 0.35}) {
  final config = PerformanceConfig.instance;

  if (!config.useComplexShadows) {
    return [
      BoxShadow(
        color: color.withValues(alpha:opacity * 0.3),
        blurRadius: 8,
      ),
    ];
  }

  return [
    BoxShadow(
      color: color.withValues(alpha:opacity),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
}

/// Optimized gradient that can fall back to solid color
BoxDecoration optimizedGradientDecoration({
  required LinearGradient gradient,
  Color? fallbackColor,
  BorderRadius? borderRadius,
  List<BoxShadow>? boxShadow,
  Border? border,
}) {
  final config = PerformanceConfig.instance;

  if (!config.useGradients) {
    return BoxDecoration(
      color: fallbackColor ?? gradient.colors.first,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      border: border,
    );
  }

  return BoxDecoration(
    gradient: gradient,
    borderRadius: borderRadius,
    boxShadow: boxShadow,
    border: border,
  );
}

/// Fast animation curve for snappy interactions
const Curve fastOutCurve = Curves.easeOutCubic;
const Curve fastInOutCurve = Curves.easeInOutCubic;

/// Optimized TweenAnimationBuilder wrapper
class OptimizedTween extends StatelessWidget {
  final double begin;
  final double end;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext, double, Widget?) builder;
  final Widget? child;

  const OptimizedTween({
    super.key,
    this.begin = 0.0,
    this.end = 1.0,
    required this.duration,
    this.curve = Curves.easeOutCubic,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: adaptiveDuration(duration),
      curve: curve,
      builder: builder,
      child: child,
    );
  }
}

/// Optimized list item animation - skips animation on low-end devices
class OptimizedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final int staggerDelayMs;

  const OptimizedListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 200),
    this.staggerDelayMs = 30,
  });

  @override
  Widget build(BuildContext context) {
    final config = PerformanceConfig.instance;

    // Skip animations for low-end devices
    if (config.mode == PerformanceMode.low) {
      return child;
    }

    final staggerDelay =
        (staggerDelayMs * index).clamp(0, config.maxStaggerDelayMs * 3);
    final duration = adaptiveDuration(baseDuration);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: duration.inMilliseconds + staggerDelay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// RepaintBoundary wrapper for complex widgets
class IsolatedRepaint extends StatelessWidget {
  final Widget child;

  const IsolatedRepaint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

/// Lightweight card without heavy effects
class LightweightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;

  const LightweightCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1C1E26),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha:0.08),
              width: 1,
            ),
      ),
      child: child,
    );
  }
}

/// Minimal animation wrapper for fade only (fastest)
class SimpleFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SimpleFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<SimpleFadeIn> createState() => _SimpleFadeInState();
}

class _SimpleFadeInState extends State<SimpleFadeIn> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Use post frame callback for smoother initial animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: adaptiveDuration(widget.duration),
      curve: Curves.easeOut,
      child: widget.child,
    );
  }
}

/// Extension for easy performance-aware widget wrapping
extension PerformanceExtensions on Widget {
  /// Wrap with RepaintBoundary for isolation
  Widget isolated() => RepaintBoundary(child: this);

  /// Wrap with simple fade animation
  Widget fadeIn([Duration duration = const Duration(milliseconds: 150)]) {
    return SimpleFadeIn(duration: duration, child: this);
  }
}
