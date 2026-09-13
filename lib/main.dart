import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parking/src/features/user/user_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:parking/src/features/booking/booking_screen.dart';
import 'package:parking/src/features/onboarding/onboarding_screen.dart';
import 'package:parking/src/services/auth_service.dart';
import 'package:parking/src/services/firestore_service.dart';

import 'src/Screen/Splash.dart';
import 'src/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/onboarding', // ← ADD THIS
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            // ✅ Extract slotId from extra
            final extra = state.extra as Map<String, dynamic>?;
            final slotId = extra?['slotId'] as String?;

            print('🚀 Router: Navigating to /detail');
            print('📦 Router: extra = $extra');
            print('🎯 Router: slotId = $slotId');

            return UserDetailScreen(slotId: slotId, userId: null);
          },
        ),

        GoRoute(
          path: '/booking',
          builder: (context, state) => const BookingScreen(),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SmartPark',
        theme: appTheme,
        routerConfig: router,
      ),
    );
  }
}
