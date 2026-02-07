import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'performance.dart';

// ============================================================================
// INDUSTRY-STANDARD ANIMATION CONSTANTS
// Based on Material Design 3 & Apple HIG motion guidelines
// ============================================================================

/// Standard durations following Material Design 3 specs
class AnimationDurations {
  /// Extra short - micro interactions (50-100ms)
  static const Duration extraShort = Duration(milliseconds: 50);

  /// Short - button presses, toggles (100-150ms)
  static const Duration short = Duration(milliseconds: 100);

  /// Medium short - component state changes (150-200ms)
  static const Duration mediumShort = Duration(milliseconds: 150);

  /// Medium - standard transitions (200-300ms)
  static const Duration medium = Duration(milliseconds: 250);

  /// Medium long - modal/dialog transitions (300-400ms)
  static const Duration mediumLong = Duration(milliseconds: 350);

  /// Long - complex transitions (400-500ms)
  static const Duration long = Duration(milliseconds: 450);

  /// Extra long - splash/onboarding animations (500ms+)
  static const Duration extraLong = Duration(milliseconds: 600);
}

/// Industry-standard easing curves
class AnimationCurves {
  /// Standard Material 3 easing - most common
  static const Curve standard = Cubic(0.2, 0.0, 0, 1.0);

  /// Emphasized - for important transitions
  static const Curve emphasized = Cubic(0.2, 0.0, 0, 1.0);

  /// Emphasized decelerate - entering elements
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized accelerate - exiting elements
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Standard decelerate - quick start, smooth end
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0, 1.0);

  /// Standard accelerate - smooth start, quick end
  static const Curve standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// iOS-style spring curve
  static const Curve appleSpring = Cubic(0.28, 0.11, 0.32, 1.0);

  /// Bounce effect - for playful interactions
  static const Curve bounce = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Overshoot - subtle spring overshoot
  static const Curve overshoot = Cubic(0.34, 1.3, 0.64, 1.0);

  /// Smooth scroll deceleration
  static const Curve scrollDecelerate = Cubic(0.0, 0.0, 0.2, 1.0);
}

/// Spring simulation parameters for physics-based animations
class SpringParams {
  /// Gentle spring - subtle bounce
  static SpringDescription get gentle => const SpringDescription(
        mass: 1.0,
        stiffness: 300.0,
        damping: 20.0,
      );

  /// Responsive spring - quick and snappy
  static SpringDescription get responsive => const SpringDescription(
        mass: 1.0,
        stiffness: 500.0,
        damping: 25.0,
      );

  /// Bouncy spring - noticeable overshoot
  static SpringDescription get bouncy => const SpringDescription(
        mass: 1.0,
        stiffness: 400.0,
        damping: 15.0,
      );

  /// Stiff spring - minimal bounce, quick settle
  static SpringDescription get stiff => const SpringDescription(
        mass: 1.0,
        stiffness: 700.0,
        damping: 30.0,
      );
}

// ============================================================================
// PREMIUM PAGE TRANSITIONS
// ============================================================================

/// iOS-style page route with smooth spring physics
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;
  final bool enableSecondaryAnimation;

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.right,
    this.enableSecondaryAnimation = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use smaller offset for premium feel
            Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(0.25, 0.0);
                break;
              case SlideDirection.left:
                begin = const Offset(-0.25, 0.0);
                break;
              case SlideDirection.up:
                begin = const Offset(0.0, 0.15);
                break;
              case SlideDirection.down:
                begin = const Offset(0.0, -0.15);
                break;
            }

            // Primary animation - incoming page
            final slideAnimation = Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.emphasizedDecelerate,
              reverseCurve: AnimationCurves.emphasizedAccelerate,
            ));

            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
            );

            // Secondary animation - outgoing page parallax
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: Offset(direction == SlideDirection.right ? -0.1 : 0.1, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: AnimationCurves.standard,
            ));

            final secondaryFade = Tween<double>(begin: 1.0, end: 0.92).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: AnimationCurves.standard,
              ),
            );

            Widget result = FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );

            // Apply secondary animation to outgoing page
            if (enableSecondaryAnimation) {
              result = SlideTransition(
                position: secondarySlide,
                child: FadeTransition(
                  opacity: secondaryFade,
                  child: result,
                ),
              );
            }

            return result;
          },
          transitionDuration: AnimationDurations.mediumLong,
          reverseTransitionDuration: AnimationDurations.medium,
        );
}

enum SlideDirection { right, left, up, down }

/// Premium fade + scale transition for dialogs and modals
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({
    required this.page,
    super.barrierDismissible = false,
  }) : super(
          opaque: false,
          barrierColor: Colors.black54,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use emphasized curve for premium feel
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: AnimationCurves.emphasizedDecelerate,
                reverseCurve: AnimationCurves.emphasizedAccelerate,
              ),
            );

            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: AnimationDurations.medium,
          reverseTransitionDuration: AnimationDurations.mediumShort,
        );
}

/// Modal bottom sheet transition with spring physics
class ModalSheetRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ModalSheetRoute({required this.page})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.emphasizedDecelerate,
              reverseCurve: AnimationCurves.emphasizedAccelerate,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
          transitionDuration: AnimationDurations.mediumLong,
          reverseTransitionDuration: AnimationDurations.medium,
        );
}

/// Shared axis transition (Material 3 style)
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisType type;

  SharedAxisPageRoute({
    required this.page,
    this.type = SharedAxisType.horizontal,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final Offset slideOffset;
            switch (type) {
              case SharedAxisType.horizontal:
                slideOffset = const Offset(0.15, 0.0);
                break;
              case SharedAxisType.vertical:
                slideOffset = const Offset(0.0, 0.15);
                break;
              case SharedAxisType.scaled:
                slideOffset = Offset.zero;
                break;
            }

            // Primary page entering
            final enterSlide = Tween<Offset>(
              begin: slideOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.emphasizedDecelerate,
            ));

            final enterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
              ),
            );

            final enterScale = type == SharedAxisType.scaled
                ? Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
                    parent: animation,
                    curve: AnimationCurves.emphasizedDecelerate,
                  ))
                : const AlwaysStoppedAnimation(1.0);

            // Secondary page exiting
            final exitSlide = Tween<Offset>(
              begin: Offset.zero,
              end: Offset(-slideOffset.dx, -slideOffset.dy),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: AnimationCurves.emphasizedAccelerate,
            ));

            final exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
              ),
            );

            Widget result = FadeTransition(
              opacity: enterFade,
              child: SlideTransition(
                position: enterSlide,
                child: ScaleTransition(
                  scale: enterScale,
                  child: child,
                ),
              ),
            );

            return SlideTransition(
              position: exitSlide,
              child: FadeTransition(
                opacity: exitFade,
                child: result,
              ),
            );
          },
          transitionDuration: AnimationDurations.medium,
        );
}

enum SharedAxisType { horizontal, vertical, scaled }

// ============================================================================
// STAGGERED LIST ANIMATIONS
// ============================================================================

/// Premium staggered animation for list items
class StaggeredListAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final int staggerDelayMs;
  final int maxDelayMs;
  final bool slideFromLeft;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.staggerDelayMs = 35,
    this.maxDelayMs = 300,
    this.slideFromLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = PerformanceConfig.instance;

    // Skip animations for low-end devices
    if (config.mode == PerformanceMode.low) {
      return child;
    }

    final delay = (staggerDelayMs * index).clamp(0, maxDelayMs);
    final totalDuration = Duration(
      milliseconds: adaptiveDuration(duration).inMilliseconds + delay,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: totalDuration,
      curve: AnimationCurves.emphasizedDecelerate,
      builder: (context, value, child) {
        // Apply delay by adjusting the progress
        final delayProgress = delay / totalDuration.inMilliseconds;
        final adjustedValue =
            ((value - delayProgress) / (1 - delayProgress)).clamp(0.0, 1.0);

        return Opacity(
          opacity: adjustedValue,
          child: Transform.translate(
            offset: Offset(
              slideFromLeft ? -16 * (1 - adjustedValue) : 0,
              12 * (1 - adjustedValue),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// High-performance animated list item with spring physics
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration? delay;
  final bool enableSlide;
  final bool enableScale;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay,
    this.enableSlide = true,
    this.enableScale = false,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.mediumLong,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.emphasizedDecelerate,
    ));

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationCurves.emphasizedDecelerate,
      ),
    );

    // Calculate stagger delay
    final config = PerformanceConfig.instance;
    final staggerMs = config.mode == PerformanceMode.low
        ? 0
        : config.mode == PerformanceMode.medium
            ? 25
            : 35;
    final maxDelay = config.maxStaggerDelayMs * 4;

    Future.delayed(
      widget.delay ??
          Duration(milliseconds: (staggerMs * widget.index).clamp(0, maxDelay)),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;

    if (widget.enableSlide) {
      result = SlideTransition(
        position: _slideAnimation,
        child: result,
      );
    }

    if (widget.enableScale) {
      result = ScaleTransition(
        scale: _scaleAnimation,
        child: result,
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: result,
    );
  }
}

// ============================================================================
// MICRO-INTERACTIONS & FEEDBACK ANIMATIONS
// ============================================================================

/// Subtle breathing/pulse animation for attention-grabbing elements
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool enabled;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
    this.minScale = 0.97,
    this.maxScale = 1.03,
    this.enabled = true,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Use sine curve for smoother breathing effect
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.5; // Reset to middle
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

/// Premium shimmer loading effect with improved performance
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final double angle;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.angle = 0.0,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    // Smooth linear animation for shimmer sweep
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? const Color(0xFF2A2D3A) : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? const Color(0xFF3D4155) : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Gradient transform for sliding shimmer effect
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Spring bounce animation for tap feedback with haptics
class BounceAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration duration;
  final double scaleValue;
  final bool enableHaptics;
  final bool useSpring;

  const BounceAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.duration = const Duration(milliseconds: 100),
    this.scaleValue = 0.95,
    this.enableHaptics = true,
    this.useSpring = true,
  });

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _setupAnimation();
  }

  void _setupAnimation() {
    _animation = Tween<double>(begin: 1.0, end: widget.scaleValue).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationCurves.emphasized,
        reverseCurve: widget.useSpring
            ? AnimationCurves.overshoot
            : AnimationCurves.emphasized,
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    if (_isPressed) return;
    _isPressed = true;
    _controller.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _isPressed = false;
    _controller.reverse().then((_) {
      widget.onTap?.call();
    });
  }

  void _onTapCancel() {
    _isPressed = false;
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

/// Premium fade in animation with optional slide
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset? slideOffset;
  final double? scaleFrom;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.curve = AnimationCurves.emphasizedDecelerate,
    this.slideOffset,
    this.scaleFrom,
  });

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset>? _slideAnimation;
  late Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: adaptiveDuration(widget.duration),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: widget.curve),
      ),
    );

    if (widget.slideOffset != null) {
      _slideAnimation = Tween<Offset>(
        begin: widget.slideOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
    } else {
      _slideAnimation = null;
    }

    if (widget.scaleFrom != null) {
      _scaleAnimation = Tween<double>(
        begin: widget.scaleFrom,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
    } else {
      _scaleAnimation = null;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );

    if (_slideAnimation != null) {
      result = SlideTransition(
        position: _slideAnimation!,
        child: result,
      );
    }

    if (_scaleAnimation != null) {
      result = ScaleTransition(
        scale: _scaleAnimation!,
        child: result,
      );
    }

    return result;
  }
}

/// Premium slide in animation with spring physics
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;
  final bool enableFade;

  const SlideInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.12),
    this.enableFade = true,
  });

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: adaptiveDuration(widget.duration),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationCurves.emphasizedDecelerate,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = SlideTransition(
      position: _slideAnimation,
      child: widget.child,
    );

    if (widget.enableFade) {
      result = FadeTransition(
        opacity: _fadeAnimation,
        child: result,
      );
    }

    return result;
  }
}

// ============================================================================
// INTERACTIVE BUTTONS & TAP FEEDBACK
// ============================================================================

/// Premium interactive button with scale feedback and haptics
class ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleValue;
  final Duration duration;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const ScaleTapButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleValue = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<ScaleTapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleValue).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationCurves.emphasized,
        reverseCurve: AnimationCurves.overshoot,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      behavior: widget.behavior,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Tilt effect button with 3D perspective
class TiltButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt;
  final Duration duration;

  const TiltButton({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = 0.05,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<TiltButton> createState() => _TiltButtonState();
}

class _TiltButtonState extends State<TiltButton> {
  double _rotateX = 0;
  double _rotateY = 0;
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(event.position);
    final center = Offset(box.size.width / 2, box.size.height / 2);

    setState(() {
      _isPressed = true;
      _rotateX = (localPosition.dy - center.dy) / center.dy * -widget.maxTilt;
      _rotateY = (localPosition.dx - center.dx) / center.dx * widget.maxTilt;
    });
    HapticFeedback.lightImpact();
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _isPressed = false;
      _rotateX = 0;
      _rotateY = 0;
    });
    widget.onTap?.call();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _isPressed = false;
      _rotateX = 0;
      _rotateY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _isPressed ? 1 : 0),
        duration: widget.duration,
        curve: AnimationCurves.emphasized,
        builder: (context, progress, child) {
          final s = 1.0 - (0.03 * progress);
          return Transform.scale(
            scaleX: s,
            scaleY: s,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_rotateX * progress)
                ..rotateY(_rotateY * progress),
              alignment: Alignment.center,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADERS
// ============================================================================

/// Premium skeleton loading placeholder
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor ?? const Color(0xFF2A2D3A),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton card placeholder with realistic shape
class SkeletonCard extends StatelessWidget {
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3A),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton list builder with staggered loading
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool staggered;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.staggered = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (staggered) {
          return AnimatedListItem(
            index: index,
            child: SkeletonCard(height: itemHeight),
          );
        }
        return SkeletonCard(height: itemHeight);
      },
    );
  }
}

// ============================================================================
// SPECIAL EFFECTS & MARKERS
// ============================================================================

/// Soft pulse animation for markers with ripple effect
class MarkerPulse extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final double maxRadius;
  final int rippleCount;

  const MarkerPulse({
    super.key,
    required this.child,
    this.pulseColor = Colors.blue,
    this.maxRadius = 35,
    this.rippleCount = 2,
  });

  @override
  State<MarkerPulse> createState() => _MarkerPulseState();
}

class _MarkerPulseState extends State<MarkerPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Multiple ripples for smoother effect
        ...List.generate(widget.rippleCount, (i) {
          final offset = i / widget.rippleCount;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = (_controller.value + offset) % 1.0;
              final scale = 0.5 + (progress * 0.5);
              final opacity = (1.0 - progress) * 0.3;

              return Container(
                width: widget.maxRadius * 2 * scale,
                height: widget.maxRadius * 2 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.pulseColor.withValues(alpha: opacity),
                ),
              );
            },
          );
        }),
        widget.child,
      ],
    );
  }
}

/// Animated success checkmark with spring bounce
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onComplete;
  final Duration delay;

  const AnimatedCheckmark({
    super.key,
    this.size = 60,
    this.color = Colors.green,
    this.backgroundColor,
    this.onComplete,
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AnimationDurations.mediumLong,
      vsync: this,
    );

    _checkController = AnimationController(
      duration: AnimationDurations.medium,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: AnimationCurves.bounce,
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: AnimationCurves.emphasizedDecelerate,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _scaleController.forward().then((_) {
          _checkController.forward().then((_) {
            HapticFeedback.mediumImpact();
            Future.delayed(const Duration(milliseconds: 400), () {
              widget.onComplete?.call();
            });
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.backgroundColor ?? widget.color.withValues(alpha: 0.15),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _checkAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _CheckPainter(
                progress: _checkAnimation.value,
                color: widget.color,
                strokeWidth: widget.size * 0.08,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for animated checkmark
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Checkmark path points
    final start = Offset(center.dx - radius * 0.5, center.dy);
    final mid = Offset(center.dx - radius * 0.1, center.dy + radius * 0.35);
    final end = Offset(center.dx + radius * 0.5, center.dy - radius * 0.3);

    final path = Path();

    if (progress <= 0.5) {
      // First half: draw the short part of checkmark
      final t = progress * 2;
      path.moveTo(start.dx, start.dy);
      path.lineTo(
        lerpDouble(start.dx, mid.dx, t)!,
        lerpDouble(start.dy, mid.dy, t)!,
      );
    } else {
      // Second half: complete the checkmark
      final t = (progress - 0.5) * 2;
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(
        lerpDouble(mid.dx, end.dx, t)!,
        lerpDouble(mid.dy, end.dy, t)!,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ============================================================================
// NAVIGATION HELPERS
// ============================================================================

/// Premium navigation helper with smooth transitions
class AppNavigator {
  /// Push with slide from right (default)
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      SlidePageRoute(page: page, direction: SlideDirection.right),
    );
  }

  /// Push with slide from bottom (for modals)
  static Future<T?> pushModal<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute(page: page),
    );
  }

  /// Push with fade + scale (for dialogs)
  static Future<T?> pushDialog<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      FadeScalePageRoute(page: page, barrierDismissible: true),
    );
  }

  /// Shared axis horizontal transition
  static Future<T?> pushSharedAxis<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      SharedAxisPageRoute(page: page, type: SharedAxisType.horizontal),
    );
  }

  /// Replace with slide transition
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      SlidePageRoute(page: page, direction: SlideDirection.right),
    );
  }

  /// Replace with fade scale transition
  static Future<T?> pushReplacementFade<T, TO>(
      BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      FadeScalePageRoute(page: page),
    );
  }

  /// Pop with implicit reverse animation
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  /// Pop until predicate
  static void popUntil(BuildContext context, RoutePredicate predicate) {
    Navigator.of(context).popUntil(predicate);
  }

  /// Push and remove all
  static Future<T?> pushAndRemoveAll<T>(BuildContext context, Widget page) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      FadeScalePageRoute(page: page),
      (route) => false,
    );
  }
}

// ============================================================================
// SNACKBAR & TOAST HELPERS
// ============================================================================

/// Premium animated snackbar helper
class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF323232),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        action: action,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void success(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF22C55E),
    );
  }

  static void error(BuildContext context, String message,
      {VoidCallback? onRetry}) {
    HapticFeedback.heavyImpact();
    show(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFEF4444),
      onRetry: onRetry,
      duration: const Duration(seconds: 5),
    );
  }

  static void info(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    show(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFF3B82F6),
    );
  }

  static void warning(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      backgroundColor: const Color(0xFFF59E0B),
    );
  }
}

// ============================================================================
// WIDGET EXTENSIONS
// ============================================================================

/// Animation extensions for widgets
extension AnimationExtensions on Widget {
  /// Wrap with fade in animation
  Widget withFadeIn({
    Duration duration = AnimationDurations.medium,
    Duration delay = Duration.zero,
    Offset? slideOffset,
    double? scaleFrom,
  }) {
    return FadeInAnimation(
      duration: duration,
      delay: delay,
      slideOffset: slideOffset,
      scaleFrom: scaleFrom,
      child: this,
    );
  }

  /// Wrap with slide in animation
  Widget withSlideIn({
    Duration duration = AnimationDurations.mediumLong,
    Duration delay = Duration.zero,
    Offset beginOffset = const Offset(0, 0.12),
  }) {
    return SlideInAnimation(
      duration: duration,
      delay: delay,
      beginOffset: beginOffset,
      child: this,
    );
  }

  /// Wrap with bounce tap effect
  Widget withBounce({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enableHaptics = true,
  }) {
    return BounceAnimation(
      onTap: onTap,
      onLongPress: onLongPress,
      enableHaptics: enableHaptics,
      child: this,
    );
  }

  /// Wrap with scale tap effect
  Widget withScaleTap({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double scale = 0.96,
    bool enableHaptics = true,
  }) {
    return ScaleTapButton(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleValue: scale,
      enableHaptics: enableHaptics,
      child: this,
    );
  }

  /// Wrap with pulse animation
  Widget withPulse({bool enabled = true}) {
    return PulseAnimation(enabled: enabled, child: this);
  }

  /// Wrap with RepaintBoundary for performance isolation
  Widget isolated() => RepaintBoundary(child: this);

  /// Wrap with shimmer loading
  Widget withShimmer() => ShimmerLoading(child: this);

  /// Wrap with staggered animation
  Widget staggered(int index, {int staggerDelayMs = 35}) {
    return StaggeredListAnimation(
      index: index,
      staggerDelayMs: staggerDelayMs,
      child: this,
    );
  }
}

// ============================================================================
// SCROLL PHYSICS
// ============================================================================

/// Premium bouncing scroll physics (iOS-style)
class PremiumScrollPhysics extends BouncingScrollPhysics {
  const PremiumScrollPhysics({super.parent});

  @override
  PremiumScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PremiumScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 120.0,
        damping: 1.1,
      );
}

/// Snap scroll physics for paginated content
class SnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const SnapScrollPhysics({
    super.parent,
    required this.itemExtent,
  });

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapScrollPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
    );
  }

  double _getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 100.0,
        damping: 1.0,
      );
}

// ============================================================================
// UTILITY ANIMATIONS
// ============================================================================

/// Smooth count animation for numbers
class AnimatedNumber extends StatelessWidget {
  final num value;
  final Duration duration;
  final TextStyle? style;
  final String Function(num)? formatter;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.duration = AnimationDurations.medium,
    this.style,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween(end: value),
      duration: duration,
      curve: AnimationCurves.emphasizedDecelerate,
      builder: (context, val, child) {
        final formatted = formatter?.call(val) ?? val.toStringAsFixed(0);
        return Text(formatted, style: style);
      },
    );
  }
}

/// Animated progress indicator with smooth transitions
class AnimatedProgress extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedProgress({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 4,
    this.duration = AnimationDurations.medium,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: AnimationCurves.emphasizedDecelerate,
      builder: (context, progress, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.1),
            borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).primaryColor,
                borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Typing text animation effect
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDelay;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDelay = const Duration(milliseconds: 50),
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _typeNextChar();
  }

  void _typeNextChar() {
    if (_currentIndex < widget.text.length) {
      Future.delayed(widget.charDelay, () {
        if (mounted) {
          setState(() {
            _displayedText = widget.text.substring(0, _currentIndex + 1);
            _currentIndex++;
          });
          _typeNextChar();
        }
      });
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
