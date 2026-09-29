import '../../../../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:swam_match_app/core/constants/colors.dart';
import 'custom_login_page.dart';

class AppealFormPage extends StatefulWidget {
  const AppealFormPage({super.key});

  @override
  State<AppealFormPage> createState() => _AppealFormPageState();
}

class _AppealFormPageState extends State<AppealFormPage> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitAppeal() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide a detailed reason (min 10 characters).',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('submitAppeal').call({'reason': reason});

      setState(() => _isSubmitted = true);

      // Brief confirmation then sign out
      await Future.delayed(const Duration(seconds: 3));
      await AuthService.instance.signOut(); // clears push token too
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomLoginPage()),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Failed to submit appeal. Please try again.',
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  /// A suspended account must not get back into the app from here: leaving
  /// this page (back arrow / Android back / swipe) signs out to the login page.
  Future<void> _leave() async {
    if (_isSubmitted) return; // already signing out after submitting
    await AuthService.instance.signOut(); // clears push token too
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidian,
        appBar: AppBar(
          backgroundColor: AppColors.obsidian,
          title: const Text('Submit Appeal'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Sign out',
            onPressed: _isSubmitting ? null : _leave,
          ),
        ),
        body: _isSubmitted
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 24),
                      Text(
                        'Appeal Submitted',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your appeal has been received. You will be signed out.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explain why your account should be reinstated:',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _reasonController,
                        maxLines: null,
                        maxLength: 2000,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'I believe my account was suspended in error because...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.goldMedium,
                            ),
                          ),
                          counterStyle: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitAppeal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Submit Appeal',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
