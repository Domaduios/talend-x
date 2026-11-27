import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';

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
  late Animation<double> _logoAnimation;
  late Animation<double> _logoRotation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoRotation = Tween<double>(
      begin: -math.pi,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    // Loading animation
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _textController.forward();
    });

    // Navigate after splash animation completes
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    try {
      // Check if it's first time
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('is_first_time') ?? true;

      print('Is First Time: $isFirstTime'); // Debug

      if (!mounted) return;

      if (SupabaseService.currentUser != null) {
        final profile = await SupabaseDb.instance
            .collection('users')
            .doc(SupabaseService.currentUser!.id)
            .get();
        if (!mounted) return;
        if (profile.exists && profile.data()['profileCompleted'] == true) {
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }

      if (isFirstTime) {
        // Mark as not first time
        await prefs.setBool('is_first_time', false);
        print('Navigating to Welcome Screen'); // Debug

        if (!mounted) return;

        // Navigate to Welcome Screen using named route
        Navigator.pushReplacementNamed(context, '/welcome');
      } else {
        print('Navigating to Sign In Screen'); // Debug
        // Navigate to Sign In screen
        Navigator.pushReplacementNamed(context, '/signin');
      }
    } catch (e) {
      print('Error in navigation: $e'); // Debug
      // If there's an error, just navigate to Sign In
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Stack(
          children: [
            // Floating particles
            ...List.generate(20, (index) => _buildParticle(index)),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value * 0.3 + 0.7,
                        child: Transform.rotate(
                          angle: _logoRotation.value,
                          child: Opacity(
                            opacity: _logoAnimation.value,
                            child: _buildHexagonLogo(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // App Name
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textAnimation),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TALENT',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 6),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'X',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 6),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textAnimation),
                      child: const Text(
                        'UNLOCK YOUR POTENTIAL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Loading Bar
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SizedBox(
                      width: 180,
                      height: 3,
                      child: AnimatedBuilder(
                        animation: _loadingController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: LoadingBarPainter(
                              progress: _loadingController.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexagonLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: CustomPaint(
        painter: HexagonPainter(),
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, double value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: const Text(
              'TX',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -3,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 4),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticle(int index) {
    final random = math.Random(index);
    final size = random.nextDouble() * 35 + 15;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * MediaQuery.of(context).size.height;
    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 4000 + random.nextInt(2000)),
        curve: Curves.easeInOut,
        builder: (context, double value, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(value * 2 * math.pi) * 25,
              -math.cos(value * 2 * math.pi) * 40,
            ),
            child: Opacity(
              opacity: (0.3 + (math.sin(value * 2 * math.pi) * 0.5)).clamp(
                0.0,
                1.0,
              ),
              child: child,
            ),
          );
        },
        onEnd: () {
          setState(() {});
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// Hexagon Painter
class HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = _createHexagonPath(size);
    canvas.drawPath(path, paint);

    // Inner hexagon with gradient
    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final innerPath = _createHexagonPath(
      Size(size.width * 0.9, size.height * 0.9),
    );
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.drawPath(innerPath, innerPaint);
  }

  Path _createHexagonPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.3, 0);
    path.lineTo(w * 0.7, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.7, h);
    path.lineTo(w * 0.3, h);
    path.lineTo(0, h * 0.5);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Loading Bar Painter
class LoadingBarPainter extends CustomPainter {
  final double progress;

  LoadingBarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Progress
    double width;
    double left;
    if (progress < 0.5) {
      width = size.width * (progress * 2) * 0.8;
      left = 0;
    } else {
      width = size.width * ((1 - progress) * 2) * 0.8;
      left = size.width * ((progress - 0.5) * 2);
    }

    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, width, size.height),
      const Radius.circular(10),
    );
    canvas.drawRRect(progressRect, progressPaint);
  }

  @override
  bool shouldRepaint(LoadingBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
