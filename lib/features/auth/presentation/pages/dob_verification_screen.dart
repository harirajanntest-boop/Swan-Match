import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'package:swam_match_app/services/auth_service.dart';
import 'package:swam_match_app/services/user_service.dart';
import 'package:swam_match_app/features/auth/presentation/pages/onboarding_flow.dart';

class DobVerificationScreen extends StatefulWidget {
  // If these are provided, it's an Email/Password sign-up. 
  // If they are null, it's a Google sign-up relying on pending credentials.
  final String? email;
  final String? password;
  final String? name;

  const DobVerificationScreen({
    super.key, 
    this.email, 
    this.password, 
    this.name,
  });

  @override
  State<DobVerificationScreen> createState() => _DobVerificationScreenState();
}

class _DobVerificationScreenState extends State<DobVerificationScreen> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _errorText;

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || 
       (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.goldMedium,
              onPrimary: Colors.black,
              surface: AppColors.onyx,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.obsidian,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _errorText = null;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleVerification() async {
    if (_selectedDate == null) {
      setState(() => _errorText = 'Please select your Date of Birth.');
      return;
    }

    final age = _calculateAge(_selectedDate!);

    if (age < 18) {
      // Security: Discard any pending Google credentials
      AuthService.instance.clearTemporaryCredentials();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.onyx,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Access Denied",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "You must be at least 18 years old to use Swan Match.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to signup screen
              },
              child: const Text(
                "OK",
                style: TextStyle(color: AppColors.goldMedium),
              ),
            )
          ],
        )
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user;

      // FLOW A: Email / Password
      if (widget.email != null && widget.password != null) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: widget.email!, 
              password: widget.password!
            );
        user = credential.user;
        
        if (user != null) {
          await UserService.instance.upsertUserProfile(
            uid: user.uid,
            data: {
              'uid': user.uid,
              'name': widget.name ?? '',
              'email': widget.email,
              'dob': _selectedDate!.toIso8601String(), // Store DOB
              'age': age,
              'registrationCompleted': false,
              'createdAt': DateTime.now(),
              'updatedAt': DateTime.now(),
            },
          );
        }
      } 
      // FLOW B: Google Sign-In
      else if (AuthService.instance.hasPendingCredentials) {
        final credential = await AuthService.instance.completeDelayedSignIn();
        user = credential.user;

        if (user != null) {
          final profile = await UserService.instance.getUserProfile(user.uid);
          
          if (profile == null) {
            // New Google User
            final googlePhoto = user.photoURL ?? '';
            await UserService.instance.upsertUserProfile(
              uid: user.uid,
              data: {
                'uid': user.uid,
                'name': user.displayName ?? '',
                'email': user.email ?? '',
                'dob': _selectedDate!.toIso8601String(), // Store DOB
                'age': age,
                'photos': googlePhoto.isNotEmpty ? [googlePhoto] : [],
                'registrationCompleted': false,
                'createdAt': DateTime.now(),
                'updatedAt': DateTime.now(),
              },
            );
          }
        }
      }

      if (!mounted) return;

      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          (route) => false,
        );
      } else {
        _showError('Authentication failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        _showError('An account already exists with this email.');
      } else {
        _showError(AuthService.instance.readableAuthError(e));
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium),
          onPressed: () {
            AuthService.instance.clearTemporaryCredentials();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              Text(
                "When is your birthday?",
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                "You must be at least 18 years old to use Swan Match. Your age will be public.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Date picker button
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.onyx,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _errorText != null ? Colors.red : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null 
                            ? "Select Date of Birth" 
                            : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                        style: TextStyle(
                          color: _selectedDate == null ? Colors.white54 : Colors.white,
                          fontSize: 16,
                          fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.goldMedium,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldMedium,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
