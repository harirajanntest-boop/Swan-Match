import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboarding_flow.dart';

class HouseRulesScreen extends StatelessWidget {
  const HouseRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Swan Icon
                    _buildSwanIcon(),
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Welcome to Swan Match.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    const Text(
                      'Please follow these House Rules.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Rule Items
                    _buildRuleItem(
                      context,
                      'Be genuine.',
                      'Make sure your photos, age, and profile reflect who you truly are.',
                    ),
                    const SizedBox(height: 24),
                    
                    _buildRuleItem(
                      context,
                      'Stay secure.',
                      'Don\'t rush to share personal details. ',
                      hasLink: true,
                    ),
                    const SizedBox(height: 24),
                    
                    _buildRuleItem(
                      context,
                      'Be respectful.',
                      'Treat every member with the same respect you\'d expect in return.',
                    ),
                    const SizedBox(height: 24),
                    
                    _buildRuleItem(
                      context,
                      'Speak up.',
                      'Report any inappropriate behavior \u2014 help keep Swan Match safe for everyone.',
                    ),
                  ],
                ),
              ),
            ),
            
            // Sticky Bottom Button
            Container(
              padding: const EdgeInsets.all(24),
              child: _buildAgreeButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwanIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFD4A017).withOpacity(0.12),
        border: Border.all(
          color: const Color(0xFFD4A017).withOpacity(0.4),
          width: 1,
        ),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/images/image.png',
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.favorite,
            color: Color(0xFFD4A017),
            size: 28,
          );
        },
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, String title, String body, {bool hasLink = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (hasLink)
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white60,
                height: 1.6,
              ),
              children: [
                TextSpan(text: body),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Navigate to Match Safely page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Match Safely - Coming Soon!'),
                          backgroundColor: Color(0xFFD4A017),
                        ),
                      );
                    },
                    child: const Text(
                      'Match Safely',
                      style: TextStyle(
                        color: Color(0xFFD4A017),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFD4A017),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
      ],
    );
  }

  Widget _buildAgreeButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC8960C), Color(0xFFD4A017)],
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingFlow()),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'I Agree',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
