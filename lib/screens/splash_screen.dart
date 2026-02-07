import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/animations.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _ringController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<double> _loadingFadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkAuth();
  }

  void _initAnimations() {
    // Logo animation controller with spring-like duration
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Text animation controller
    _textController = AnimationController(
      vsync: this,
      duration: AnimationDurations.long,
    );

    // Loading animation controller
    _loadingController = AnimationController(
      vsync: this,
      duration: AnimationDurations.mediumLong,
    );

    // Pulse animation controller (continuous breathing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Particle animation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Ring animation controller
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Logo scale animation with premium overshoot
    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.12)
            .chain(CurveTween(curve: AnimationCurves.emphasizedDecelerate)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 23,
      ),
    ]).animate(_logoController);

    // Logo subtle rotation
    _logoRotateAnimation = Tween<double>(begin: -0.12, end: 0.0).animate(
      CurvedAnimation(
          parent: _logoController, curve: AnimationCurves.overshoot),
    );

    // Title slide up animation
    _titleSlideAnimation = Tween<double>(begin: 35.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _textController, curve: AnimationCurves.emphasizedDecelerate),
    );

    // Title fade animation
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Subtitle fade animation (delayed)
    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );

    // Loading indicator fade
    _loadingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeOut),
    );

    // Pulse animation for glow effect - sine curve for breathing
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Ring animation
    _ringAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_ringController);

    // Start animations in premium sequence
    _logoController.forward().then((_) {
      _textController.forward().then((_) {
        _loadingController.forward();
      });
    });
  }

  Future<void> _checkAuth() async {
    final authProvider = context.read<AuthProvider>();

    // Wait for auth provider to finish loading saved session
    await authProvider.waitForInitialization();

    // Add minimum 2.5 second delay for UX and animations
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Navigate with premium fade transition
    if (authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        FadeScalePageRoute(page: const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        FadeScalePageRoute(page: const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primaryMid,
                  AppColors.primaryLight,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Animated particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: ParticlePainter(
                  animationValue: _particleController.value,
                ),
              );
            },
          ),

          // Animated rings
          Center(
            child: AnimatedBuilder(
              animation: _ringAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(300, 300),
                  painter: RingPainter(
                    animationValue: _ringAnimation.value,
                    pulseValue: _pulseAnimation.value,
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo with glow
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_logoController, _pulseController]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Transform.rotate(
                        angle: _logoRotateAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gradientStart.withValues(
                                    alpha: 0.3 * _pulseAnimation.value),
                                blurRadius: 30 + (15 * _pulseAnimation.value),
                                offset: const Offset(0, 10),
                                spreadRadius: 5 * _pulseAnimation.value,
                              ),
                              BoxShadow(
                                color: AppColors.gradientEnd.withValues(
                                    alpha: 0.2 * _pulseAnimation.value),
                                blurRadius: 50,
                                spreadRadius: 10 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glassmorphism overlay
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(35),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                              // Icon
                              const Icon(
                                Icons.navigation_rounded,
                                size: 70,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),

                // Animated Title with gradient
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _titleSlideAnimation.value),
                      child: Opacity(
                        opacity: _titleFadeAnimation.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, AppColors.accentLight],
                          ).createShader(bounds),
                          child: const Text(
                            'SJCEM Navigator',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Animated Subtitle
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _subtitleFadeAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '✨ Smart Campus Navigation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),

                // Premium Loading Indicator
                AnimatedBuilder(
                  animation: _loadingController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loadingFadeAnimation.value,
                      child: Column(
                        children: [
                          // Custom animated loader
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer ring
                                AnimatedBuilder(
                                  animation: _ringController,
                                  builder: (context, _) {
                                    return Transform.rotate(
                                      angle:
                                          _ringController.value * 2 * math.pi,
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            width: 2,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: AppGradients.accent,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.accent
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Inner dot
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) {
                                    return Container(
                                      width: 12 + (4 * _pulseAnimation.value),
                                      height: 12 + (4 * _pulseAnimation.value),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppGradients.accent,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Initializing...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Version info at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _loadingController,
              builder: (context, child) {
                return Opacity(
                  opacity: _loadingFadeAnimation.value * 0.5,
                  child: const Column(
                    children: [
                      Text(
                        'St. John College of Engineering',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'v2.0.0',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for animated particles
class ParticlePainter extends CustomPainter {
  final double animationValue;

  ParticlePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent particles

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final y = (baseY + animationValue * size.height * speed) % size.height;
      final radius = 1.0 + random.nextDouble() * 2.5;
      final opacity = 0.1 + random.nextDouble() * 0.3;

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Custom painter for animated rings
class RingPainter extends CustomPainter {
  final double animationValue;
  final double pulseValue;

  RingPainter({required this.animationValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw multiple expanding rings
    for (int i = 0; i < 3; i++) {
      final phase = (animationValue + i * 0.33) % 1.0;
      final radius = 60 + phase * 100;
      final opacity = (1 - phase) * 0.2 * pulseValue;

      paint.color = AppColors.accent.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.pulseValue != pulseValue;
  }
}
