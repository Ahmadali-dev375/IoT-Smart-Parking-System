import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/booking/booking_screen.dart';
import '../features/onboarding/onboarding_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const OnboardingScreen();
      },
    ),
    GoRoute(
      path: '/booking',
      builder: (BuildContext context, GoRouterState state) {
        return const BookingScreen();
      },
    ),
  ],
);
