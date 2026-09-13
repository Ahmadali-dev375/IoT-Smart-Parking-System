import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _carAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Car movement animation (left to right)
    _carAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Fade animation for text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate after animation
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.getCurrentUser();

    print('🔍 SplashScreen: Starting navigation check');
    print('👤 User: ${user?.uid ?? "null"}');

    if (user != null) {
      // User is authenticated - check for active parking session
      try {
        print('🔎 Checking for active session...');
        final activeSlotData = await _checkActiveSession(user.uid);

        print('📊 Active slot data: $activeSlotData');

        if (activeSlotData != null) {
          // User has an active parking session - navigate to detail screen
          print('✅ Active session found! Navigating to /detail');
          if (!mounted) return;
          context.go('/detail', extra: activeSlotData);
        } else {
          // No active session - navigate to booking screen
          print('❌ No active session. Navigating to /booking');
          if (!mounted) return;
          context.go('/booking');
        }
      } catch (e, stackTrace) {
        print('❗ Error checking active session: $e');
        print('Stack trace: $stackTrace');
        // On error, default to booking screen
        if (!mounted) return;
        context.go('/booking');
      }
    } else {
      // User not authenticated - navigate to onboarding
      print('🚫 User not authenticated. Navigating to /onboarding');
      context.go('/onboarding');
    }
  }

  /// Checks if the user has an active parking session
  /// Returns a Map with slotId and userId if found, otherwise null
  Future<Map<String, dynamic>?> _checkActiveSession(String userId) async {
    try {
      print('🔍 Querying Firestore for userId: $userId');

      // ✅ STRICT QUERY: Only find slots that match BOTH conditions
      final querySnapshot = await FirebaseFirestore.instance
          .collection('parking_slots')
          .where('user_id', isEqualTo: userId) // ✅ MUST match this user
          .where('status', isEqualTo: 'reserved') // ✅ MUST be reserved
          .get();

      print('📄 Query returned ${querySnapshot.docs.length} documents');

      // If no results, return null immediately - DO NOT search other users' slots
      if (querySnapshot.docs.isEmpty) {
        print('❌ No active session found for user: $userId');
        return null;
      }

      // Loop through results to find valid (non-expired) session
      for (var slotDoc in querySnapshot.docs) {
        final slotData = slotDoc.data();

        print('🔍 Checking slot: ${slotDoc.id}');
        print('📦 Slot data: $slotData');

        // ✅ DOUBLE-CHECK: Verify user_id matches (extra safety)
        if (slotData['user_id'] != userId) {
          print('⚠️ Skipping slot ${slotDoc.id} - user_id mismatch');
          continue;
        }

        // Check if session is still valid (not expired)
        if (slotData.containsKey('reserved_until')) {
          final reservedUntil = DateTime.fromMillisecondsSinceEpoch(
            slotData['reserved_until'] as int,
          );
          print('⏰ Reserved until: $reservedUntil');
          print('⏰ Current time: ${DateTime.now()}');

          if (DateTime.now().isAfter(reservedUntil)) {
            // Session expired - skip this slot
            print('⏱️ Session expired for slot ${slotDoc.id}');

            // ✅ CLEANUP: Update expired slot to available
            await FirebaseFirestore.instance
                .collection('parking_slots')
                .doc(slotDoc.id)
                .update({
                  'status': 'available',
                  'user_id': FieldValue.delete(),
                  'car_number': FieldValue.delete(),
                  'reserved_until': FieldValue.delete(),
                  'booking_duration': FieldValue.delete(),
                });
            print('🧹 Cleaned up expired slot: ${slotDoc.id}');

            continue; // Check next slot
          }
        }

        // ✅ VALID SESSION FOUND!
        print('✅ Found valid session for user ${userId}: ${slotDoc.id}');
        return {'slotId': slotDoc.id, 'userId': userId};
      }

      // All slots were expired or invalid
      print('❌ No valid active session found for this user');
      return null;
    } catch (e, stackTrace) {
      print('❗ Error in _checkActiveSession: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background circles
              Positioned(
                top: -50,
                right: -50,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Logo and app name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: const Icon(
                              Icons.local_parking,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'SmartPark',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Find your perfect spot',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Animated car searching
                    SizedBox(
                      height: 100,
                      child: AnimatedBuilder(
                        animation: _carAnimation,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              // Road lines
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 30,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    8,
                                    (index) => Container(
                                      width: 30,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Moving car
                              Positioned(
                                left:
                                    MediaQuery.of(context).size.width *
                                        (_carAnimation.value + 1) /
                                        2 -
                                    30,
                                bottom: 35,
                                child: const FaIcon(
                                  FontAwesomeIcons.carSide,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Loading indicator
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Searching for parking...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
