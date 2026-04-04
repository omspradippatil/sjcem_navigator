import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

/// Key used to remember if the tour has been shown.
/// Shared across guest and logged-in sessions — shown once per device install.
const String _kTourShownKey = 'app_tour_shown_v1';

/// Returns true if the tour has NOT been shown yet (= first launch).
Future<bool> shouldShowTour() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kTourShownKey) ?? false);
}

/// Mark the tour as done so it never shows again.
Future<void> markTourDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTourShownKey, true);
}

// ──────────────────────────────────────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────────────────────────────────────

class _TourStep {
  final String emoji;
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final List<_TourBullet> bullets;

  const _TourStep({
    required this.emoji,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.bullets,
  });
}

class _TourBullet {
  final IconData icon;
  final String text;
  const _TourBullet(this.icon, this.text);
}

// ──────────────────────────────────────────────────────────────────────────────
// Tour steps content
// ──────────────────────────────────────────────────────────────────────────────

const List<_TourStep> _tourSteps = [
  _TourStep(
    emoji: '👋',
    title: 'Welcome to SJCEM Navigator!',
    description:
        'Your smart campus companion. Let\'s take a quick tour so you can get around in seconds.',
    icon: Icons.navigation_rounded,
    gradient: AppGradients.primary,
    bullets: [
      _TourBullet(Icons.map_rounded, 'Interactive campus map'),
      _TourBullet(Icons.route_rounded, 'Step-by-step navigation'),
      _TourBullet(Icons.school_rounded, 'Timetable & teachers'),
      _TourBullet(Icons.chat_bubble_rounded, 'Branch chat & polls'),
    ],
  ),
  _TourStep(
    emoji: '🗺️',
    title: 'The Navigation Map',
    description:
        'This is your main screen — a live floor-plan of the college. Pinch to zoom, drag to pan.',
    icon: Icons.map_rounded,
    gradient: AppGradients.info,
    bullets: [
      _TourBullet(Icons.touch_app_rounded, 'Tap any room label to see details'),
      _TourBullet(Icons.search_rounded, 'Use the search bar to find a room'),
      _TourBullet(Icons.layers_rounded, 'Switch floors with the floor buttons'),
      _TourBullet(Icons.info_outline_rounded, 'Room info sheet shows on tap'),
    ],
  ),
  _TourStep(
    emoji: '📍',
    title: 'Set Your Location',
    description:
        'Tell the app where YOU are standing right now on the map.',
    icon: Icons.my_location_rounded,
    gradient: AppGradients.accent,
    bullets: [
      _TourBullet(Icons.touch_app_rounded, 'Tap once on your current spot on the map'),
      _TourBullet(Icons.radio_button_checked_rounded, 'A red dot will appear — that\'s you!'),
      _TourBullet(Icons.explore_rounded, 'Face forward to calibrate compass direction'),
      _TourBullet(Icons.refresh_rounded, 'Tap the dot again to reposition anytime'),
    ],
  ),
  _TourStep(
    emoji: '🧭',
    title: 'Navigate to a Room',
    description:
        'Once your position is set, choose any destination and the app draws your path.',
    icon: Icons.route_rounded,
    gradient: AppGradients.success,
    bullets: [
      _TourBullet(Icons.search_rounded, 'Search or tap a room on the map'),
      _TourBullet(Icons.directions_rounded, 'Tap "Navigate" in the room info sheet'),
      _TourBullet(Icons.directions_walk_rounded, 'Follow the highlighted path line'),
      _TourBullet(Icons.stairs_rounded, 'Stair/elevator prompts guide floor changes'),
    ],
  ),
  _TourStep(
    emoji: '📋',
    title: 'Bottom Navigation Bar',
    description:
        'The floating bar at the bottom lets you jump between all features instantly.',
    icon: Icons.tab_rounded,
    gradient: AppGradients.secondary,
    bullets: [
      _TourBullet(Icons.navigation_rounded, 'Navigate — campus map (you are here!)'),
      _TourBullet(Icons.schedule_rounded, 'Timetable — today\'s class schedule'),
      _TourBullet(Icons.location_on_rounded, 'Teachers — find any teacher live'),
      _TourBullet(Icons.chat_bubble_rounded, 'Chat, Polls & Notes — more features'),
    ],
  ),
  _TourStep(
    emoji: '🎉',
    title: 'You\'re All Set!',
    description:
        'Start exploring the campus. Tap anywhere to close this tour and begin navigating.',
    icon: Icons.celebration_rounded,
    gradient: AppGradients.cosmic,
    bullets: [
      _TourBullet(Icons.help_outline_rounded, 'Need help? Tap the ⓘ icon in the app bar'),
      _TourBullet(Icons.person_rounded, 'Tap your avatar to view profile / logout'),
      _TourBullet(Icons.wifi_off_rounded, 'Works offline with cached map data'),
      _TourBullet(Icons.star_rounded, 'Happy navigating! 🎓'),
    ],
  ),
];

// ──────────────────────────────────────────────────────────────────────────────
// Public entry point – call this from HomeScreen initState
// ──────────────────────────────────────────────────────────────────────────────

/// Shows the tour overlay if this is the first launch.
/// Pass the [BuildContext] of the Scaffold so the overlay sits correctly.
Future<void> maybeShowTour(BuildContext context) async {
  if (!await shouldShowTour()) return;
  if (!context.mounted) return;
  await markTourDone();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => const _TourOverlay(),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Tour overlay widget
// ──────────────────────────────────────────────────────────────────────────────

class _TourOverlay extends StatefulWidget {
  const _TourOverlay();

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late final PageController _pageController;

  late AnimationController _fadeInController;
  late AnimationController _cardController;
  late AnimationController _dotsController;
  late Animation<double> _fadeIn;
  late Animation<double> _cardScale;
  late Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeIn = CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut);
    _cardScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );
    _cardSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    _fadeInController.forward();
    _cardController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeInController.dispose();
    _cardController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _tourSteps.length - 1) {
      _cardController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
      _cardController.forward();
    } else {
      _dismiss();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _cardController.reset();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
      _cardController.forward();
    }
  }

  void _dismiss() {
    _fadeInController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _tourSteps[_currentStep];
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Blurred backdrop ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: const Color(0xFF12141C).withValues(alpha: 0.88),
              ),
            ),

            // ── Animated particles (decorative) ──
            const _FloatingParticles(),

            // ── Main card ──
            Center(
              child: AnimatedBuilder(
                animation: _cardController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _cardSlide.value),
                    child: Transform.scale(
                      scale: _cardScale.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Gradient hero strip ──
                            _buildHeroStrip(step),
                            // ── Content area ──
                            Flexible(
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _tourSteps.length,
                                itemBuilder: (context, index) {
                                  return _buildStepContent(_tourSteps[index]);
                                },
                              ),
                            ),
                            // ── Navigation footer ──
                            _buildFooter(step),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Skip button ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.close_rounded,
                          size: 14, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStrip(_TourStep step) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      height: 140,
      decoration: BoxDecoration(
        gradient: step.gradient,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Subtle shine overlay
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25), width: 2),
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 10),
                Text(
                  step.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(_TourStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          ...step.bullets.map((b) => _buildBullet(b, step.gradient)),
        ],
      ),
    );
  }

  Widget _buildBullet(_TourBullet bullet, LinearGradient gradient) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(bullet.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                bullet.text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(_TourStep step) {
    final isLast = _currentStep == _tourSteps.length - 1;
    final isFirst = _currentStep == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // Step dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _tourSteps.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentStep ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  gradient: i == _currentStep ? step.gradient : null,
                  color: i == _currentStep
                      ? null
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Buttons row
          Row(
            children: [
              // Back button
              if (!isFirst)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (!isFirst) const SizedBox(width: 12),
              // Next / Done button
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: step.gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (step.gradient.colors.first)
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      isLast
                          ? Icons.celebration_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    label: Text(isLast ? 'Let\'s Go! 🚀' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Decorative floating particles
// ──────────────────────────────────────────────────────────────────────────────

class _FloatingParticles extends StatefulWidget {
  const _FloatingParticles();

  @override
  State<_FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<_FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ParticlePainter(_ctrl.value),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter(this.t);

  static const _positions = [
    Offset(0.1, 0.15),
    Offset(0.85, 0.08),
    Offset(0.5, 0.05),
    Offset(0.2, 0.75),
    Offset(0.78, 0.65),
    Offset(0.9, 0.4),
    Offset(0.05, 0.5),
    Offset(0.6, 0.9),
    Offset(0.35, 0.88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _positions.length; i++) {
      final phase = (t + i * 0.11) % 1.0;
      final baseX = _positions[i].dx * size.width;
      final baseY = _positions[i].dy * size.height;
      final yOffset = (phase * 60 - 30);
      final opacity = (0.5 - (phase - 0.5).abs()) * 0.4;
      final radius = 2.0 + (i % 3) * 1.5;
      paint.color =
          AppColors.gradientStart.withValues(alpha: opacity.clamp(0, 1));
      canvas.drawCircle(Offset(baseX, baseY + yOffset), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
