import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'main_dashboard.dart';

class SimpleOnboarding extends StatefulWidget {
  const SimpleOnboarding({super.key});

  @override
  State<SimpleOnboarding> createState() => _SimpleOnboardingState();
}

class _SimpleOnboardingState extends State<SimpleOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Welcome to Swan Match',
      description: 'Connect with amazing people around you. Swipe right to like, left to pass.',
      icon: Icons.favorite,
    ),
    OnboardingPageData(
      title: 'Real Connections',
      description: 'Build meaningful relationships with people who share your interests.',
      icon: Icons.people,
    ),
    OnboardingPageData(
      title: 'Start Your Journey',
      description: 'Ready to meet someone special? Let\'s get started!',
      icon: Icons.explore,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    // Mark onboarding as completed
    try {
      await UserService.instance.updateCurrentUserProfile({
        'registrationCompleted': true,
        'completedOnboardingAt': DateTime.now(),
      });
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.goldMedium,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.goldMedium.withOpacity(0.1),
                            border: Border.all(
                              color: AppColors.goldMedium,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 60,
                            color: AppColors.goldMedium,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.goldMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? AppColors.goldMedium
                          : AppColors.goldMedium.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
            
            // Action button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GoldGradientButton(
                text: _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                onPressed: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
