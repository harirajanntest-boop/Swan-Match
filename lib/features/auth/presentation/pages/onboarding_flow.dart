import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../../../services/user_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/onboarding_widgets.dart';
import 'onboarding_screens.dart';
import 'onboarding_screens_part2.dart';
import 'onboarding_screens_part3.dart';
import 'main_dashboard.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 1;
  OnboardingData _onboardingData = OnboardingData();
  
  final int _totalSteps = 14;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentStep = (_pageController.page?.round() ?? 0) + 1;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 1) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: OnboardingColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Progress Bar
              _buildProgressBar(),
              
              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Screen 1: First Name
                    FirstNameScreen(
                      data: _onboardingData,
                      onNext: (firstName) {
                        _onboardingData = _onboardingData.copyWith(firstName: firstName);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 2: Date of Birth
                    DateOfBirthScreen(
                      data: _onboardingData,
                      onNext: (dateOfBirth) {
                        _onboardingData = _onboardingData.copyWith(dateOfBirth: dateOfBirth);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 3: Gender
                    GenderScreen(
                      data: _onboardingData,
                      onNext: (gender) {
                        _onboardingData = _onboardingData.copyWith(
                          gender: gender,
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 4: Partner Preference
                    PartnerPreferenceScreen(
                      data: _onboardingData,
                      onNext: (partnerPreference) {
                        _onboardingData = _onboardingData.copyWith(partnerPreference: partnerPreference);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 5: Location
                    LocationScreen(
                      data: _onboardingData,
                      onNext: (country, state, city) {
                        _onboardingData = _onboardingData.copyWith(
                          city: city,
                          state: state,
                          country: country,
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 6: Distance Preference
                    DistancePreferenceScreen(
                      data: _onboardingData,
                      onNext: (distanceKm) {
                        _onboardingData = _onboardingData.copyWith(distanceKm: distanceKm);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 7: What Are You Looking For?
                    LookingForScreen(
                      data: _onboardingData,
                      onNext: (lookingFor) {
                        _onboardingData = _onboardingData.copyWith(lookingFor: lookingFor);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 8: Education & Profession
                    EducationProfessionScreen(
                      data: _onboardingData,
                      onNext: (qualification, university, profession) {
                        _onboardingData = _onboardingData.copyWith(
                          highestQualification: qualification,
                          university: university,
                          profession: profession,
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 9: Lifestyle Habits
                    LifestyleHabitsScreen(
                      data: _onboardingData,
                      onNext: (drinking, smoking, workout, pets) {
                        _onboardingData = _onboardingData.copyWith(
                          drinking: drinking,
                          smoking: smoking,
                          workout: workout,
                          pets: pets,
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 10: Values & Identity
                    ValuesIdentityScreen(
                      data: _onboardingData,
                      onNext: (communicationStyle, loveLanguage, educationLevel, zodiac) {
                        _onboardingData = _onboardingData.copyWith(
                          communicationStyle: communicationStyle,
                          loveLanguage: loveLanguage,
                          educationLevel: educationLevel,
                          zodiac: zodiac,
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 11: Interests
                    InterestsScreen(
                      data: _onboardingData,
                      onNext: (interests) {
                        _onboardingData = _onboardingData.copyWith(interests: interests);
                        _nextPage();
                      },
                    ),
                    
                    // Screen 12: Photos
                    PhotosScreen(
                      data: _onboardingData,
                      onNext: (photos, profilePicture) async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        // Upload photos to Firebase Storage
                        final List<String> photoUrls = [];
                        String? profilePictureUrl;

                        for (int i = 0; i < photos.length; i++) {
                          final file = File(photos[i]);
                          if (await file.exists()) {
                            try {
                              final url = await StorageService.instance.uploadProfilePhoto(
                                uid: user.uid,
                                file: file,
                              );
                              photoUrls.add(url);
                              if (i == 0) {
                                profilePictureUrl = url; // First photo is profile picture
                              }
                            } catch (e) {
                              print('Error uploading photo: $e');
                            }
                          }
                        }

                        _onboardingData = _onboardingData.copyWith(
                          photos: photoUrls,
                          profilePicture: profilePictureUrl ?? '',
                        );
                        _nextPage();
                      },
                    ),
                    
                    // Screen 13: Bio
                    BioPromptScreen(
                      data: _onboardingData,
                      onNext: (bio) {
                        _onboardingData = _onboardingData.copyWith(
                          bio: bio,
                        );
                        _completeOnboarding();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progress = _currentStep / _totalSteps;
          return Stack(
            children: [
              // Background track
              Container(
                width: constraints.maxWidth,
                height: 4,
                color: Colors.black.withOpacity(0.3),
              ),
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * progress,
                height: 4,
                decoration: BoxDecoration(
                  color: OnboardingColors.primaryGold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.heavyImpact();
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text('Saving your profile...'),
          ],
        ),
        backgroundColor: OnboardingColors.primaryGold,
        duration: Duration(seconds: 3),
      ),
    );

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Calculate age from date of birth
      int age = 0;
      if (_onboardingData.dateOfBirth != null) {
        final now = DateTime.now();
        age = now.year - _onboardingData.dateOfBirth!.year;
        if (now.month < _onboardingData.dateOfBirth!.month || 
            (now.month == _onboardingData.dateOfBirth!.month && now.day < _onboardingData.dateOfBirth!.day)) {
          age--;
        }
      }

      // Combine city, state and country into location
      String location = '';
      if (_onboardingData.city.isNotEmpty && _onboardingData.state.isNotEmpty && _onboardingData.country.isNotEmpty) {
        location = '${_onboardingData.city}, ${_onboardingData.state}, ${_onboardingData.country}';
      } else if (_onboardingData.city.isNotEmpty && _onboardingData.state.isNotEmpty) {
        location = '${_onboardingData.city}, ${_onboardingData.state}';
      } else if (_onboardingData.city.isNotEmpty && _onboardingData.country.isNotEmpty) {
        location = '${_onboardingData.city}, ${_onboardingData.country}';
      } else if (_onboardingData.city.isNotEmpty) {
        location = _onboardingData.city;
      } else if (_onboardingData.state.isNotEmpty) {
        location = _onboardingData.state;
      } else if (_onboardingData.country.isNotEmpty) {
        location = _onboardingData.country;
      }

      // Map OnboardingData fields to UserModel fields
      final profileData = {
        // Core UserModel fields
        'name': _onboardingData.firstName,
        'gender': _onboardingData.gender,
        'dateOfBirth': _onboardingData.dateOfBirth,
        'age': age,
        'bio': _onboardingData.bio,
        'photos': _onboardingData.photos,
        'interests': _onboardingData.interests,
        'location': location,
        'registrationCompleted': true,
        'updatedAt': DateTime.now(),
        
        // Additional onboarding-specific fields
        'showGender': _onboardingData.showGender,
        'partnerPreference': _onboardingData.partnerPreference,
        'city': _onboardingData.city,
        'country': _onboardingData.country,
        'distanceKm': _onboardingData.distanceKm,
        'lookingFor': _onboardingData.lookingFor,
        'highestQualification': _onboardingData.highestQualification,
        'university': _onboardingData.university,
        'profession': _onboardingData.profession,
        'drinking': _onboardingData.drinking,
        'smoking': _onboardingData.smoking,
        'workout': _onboardingData.workout,
        'pets': _onboardingData.pets,
        'communicationStyle': _onboardingData.communicationStyle,
        'loveLanguage': _onboardingData.loveLanguage,
        'educationLevel': _onboardingData.educationLevel,
        'zodiac': _onboardingData.zodiac,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      };

      // Save onboarding data to Firestore
      await UserService.instance.upsertUserProfile(
        uid: user.uid,
        data: profileData,
      );

      if (mounted) {
        // Navigate to home screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
