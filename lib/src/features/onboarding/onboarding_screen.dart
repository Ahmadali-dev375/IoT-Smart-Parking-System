import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  void _signInAnonymously() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    final user = await authService.signInAnonymously();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (user != null) {
        context.go('/booking');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to sign in. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lottie animation
                Lottie.asset(
                  'assets/park.json', // a valid JSON URL you verified
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Title - uses displayLarge from your theme
                Text(
                  'Welcome to SmartPark',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Subtitle - uses bodyLarge from your theme
                Text(
                  'Find and book a parking spot in seconds. Your hassle-free parking solution.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Button - uses your theme's ElevatedButton style
                _isLoading
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _signInAnonymously,
                          child: const Text('Get Started'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
