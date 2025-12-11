import 'package:cycle_tracking_app/src/screens/auth/login_screen.dart';
import 'package:cycle_tracking_app/src/screens/home/dashboard_screen.dart';
import 'package:cycle_tracking_app/src/services/user_preferences_service.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // Start animation
    _animationController.forward();

    // Check login status and navigate accordingly
    _checkLoginStatusAndNavigate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Check if user is logged in and navigate accordingly
  Future<void> _checkLoginStatusAndNavigate() async {
    // Wait for splash animation (minimum 2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Check if user is logged in
      final isLoggedIn = await _userPreferencesService.isLoggedIn();

      if (isLoggedIn) {
        // User is logged in, get user data and navigate to dashboard
        final userData = await _userPreferencesService.getUserData();
        if (mounted && userData != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userData: userData),
            ),
          );
        } else {
          // User data not found, navigate to login
          if (mounted) {
            _navigateToLogin();
          }
        }
      } else {
        // User is not logged in, navigate to login screen
        if (mounted) {
          _navigateToLogin();
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      // On error, navigate to login screen
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Logo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Image.asset(
                            "assets/images/logo.png",
                            width: size.width * 0.3,
                            height: size.width * 0.3,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.directions_bike,
                                size: size.width * 0.3,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),

                  // App Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_slideAnimation),
                      child: Column(
                        children: [
                          Text(
                            "Cycle Rally",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Tracking",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.08),

                  // Loading Indicator
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Version and Copyright Info
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(_slideAnimation),
                      child: Column(
                        children: [
                          Text(
                            "Version 1.0.0",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Copyright © 2025",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Powered by ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              Text(
                                "Infotrack",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
