import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_login_page.dart';
import 'blocked_profiles_page.dart';
import 'ignored_profiles_page.dart';
import 'saved_profiles_page.dart';
import 'help_support_page.dart';

class SettingsPage extends StatefulWidget {
  final bool scrollToSecurity;

  const SettingsPage({super.key, this.scrollToSecurity = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _securitySectionKey = GlobalKey();

  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _entryController.forward();
    });

    if (widget.scrollToSecurity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _securitySectionKey.currentContext != null) {
            Scrollable.ensureVisible(
              _securitySectionKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              alignment: 0.1, // Near the top
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteAccount(Map<String, dynamic> profile) async {
    final registeredName = (profile['name'] ?? '').toString().trim();
    if (registeredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile name is missing. Please update your profile first.',
          ),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.onyx,
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                'Type your name to confirm: $registeredName',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.goldMedium),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final input = controller.text.trim().toLowerCase();
                final expected = registeredName.toLowerCase();
                Navigator.pop(dialogContext, input == expected);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name did not match. Account deletion cancelled.'),
        ),
      );
      return;
    }

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) throw Exception('No authenticated user found.');

      // Step 1: Soft delete in Firestore - clear personal data
      final now = DateTime.now();
      final scheduledHardDelete = now.add(const Duration(days: 30));
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isDeleted': true,
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'scheduledHardDeleteAt': Timestamp.fromDate(scheduledHardDelete),
        // Clear personal identifiers
        'firstName': 'Deleted',
        'lastName': 'Account',
        'name': 'Deleted Account',
        'displayName': 'Deleted Account',
        'bio': '',
        'shortBio': '',
        'aboutMe': '',
        'phoneNumber': '',
        'email': '',
        'photoUrl': '',
        'profilePhotoUrl': '',
        'photos': <String>[],
        'isOnline': false,
        'online': false,
        'fcmTokens': <String>[],
      });

      // Step 2: Delete Firebase Auth account IMMEDIATELY
      // This prevents re-login via Google or any provider
      await user?.delete();

      // Step 3: Sign out (cleanup)
      await AuthService.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been scheduled for deletion.'),
        ),
      );
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomLoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'requires-recent-login') {
        _handleReauthentication();
        return;
      }

      // If the cloud function already deleted the auth account, treat it as a success!
      if (error.code == 'user-not-found') {
        await AuthService.instance.signOut();
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been successfully deleted.'),
          ),
        );
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomLoginPage()),
          (route) => false,
        );
        return;
      }

      final message = AuthService.instance.readableAuthError(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<void> _handleReauthentication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final providers = user.providerData.map((p) => p.providerId).toList();
    final isPasswordUser = providers.contains('password');

    try {
      if (isPasswordUser) {
        // Prompt for password
        final passwordController = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: AppColors.onyx,
            title: const Text(
              'Re-authenticate',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please enter your password to confirm account deletion.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _PasswordTextField(
                  controller: passwordController,
                  hint: 'Password',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );

        if (confirmed != true || passwordController.text.isEmpty) return;

        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        // Re-authenticate with Google
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Now retry delete
      await _deleteAccount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.instance.readableAuthError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _linkGoogle() async {
    try {
      await AuthService.instance.linkWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account linked successfully!')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('Email mismatch')) {
        // Show a clear dialog for email mismatch
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.onyx,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Wrong Google Account',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Text(
              errorMsg.replaceFirst('Exception: ', ''),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: AppColors.goldMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.instance.readableAuthError(e))),
        );
      }
    }
  }

  Future<void> _linkEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.onyx,
            title: const Text(
              'Link Email & Password',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.goldMedium),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PasswordTextField(
                  controller: passwordController,
                  hint: 'Password',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final pass = passwordController.text;
                        if (email.isEmpty || pass.isEmpty) return;

                        setDialogState(() => isLoading = true);
                        try {
                          await AuthService.instance.linkWithEmailAndPassword(
                            email,
                            pass,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email linked successfully!'),
                            ),
                          );
                          setState(() {});
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AuthService.instance.readableAuthError(e),
                                ),
                              ),
                            );
                          }
                        } finally {
                          setDialogState(() => isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMedium,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch link.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.obsidian,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldMedium,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Settings",
              style: TextStyle(
                color: Colors.white,
                letterSpacing: 1,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: StreamBuilder<Map<String, dynamic>?>(
                stream: UserService.instance.watchCurrentUserProfile(),
                builder: (context, snapshot) {
                  final profile = snapshot.data ?? <String, dynamic>{};
                  final profileVisibility =
                      (profile['profileVisibility'] ?? 'Public').toString();
                  final isPrivate =
                      profileVisibility == 'Private' ||
                      profile['showProfileToEveryone'] == false;
                  final showPhotosToEveryone =
                      profile['showPhotosToEveryone'] != false;

                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Privacy Settings ───
                        _SettingsSection(
                          title: "Privacy Settings",
                          icon: Icons.lock_outline,
                          children: [
                            _SettingsToggleRow(
                              label: "Private Profile",
                              subtitle: isPrivate
                                  ? "Your profile is hidden from other users."
                                  : "Your profile is visible to everyone. Toggle to make it private.",
                              value: isPrivate,
                              onChanged: (value) async {
                                await UserService.instance
                                    .updateCurrentUserProfile(<String, dynamic>{
                                      'profileVisibility': value
                                          ? 'Private'
                                          : 'Public',
                                      'showProfileToEveryone': !value,
                                    });
                              },
                            ),
                            _SettingsToggleRow(
                              label: "Show Photos to Everyone",
                              subtitle:
                                  "Turn off to hide your photos from public view.",
                              value: showPhotosToEveryone,
                              onChanged: (value) async {
                                await UserService.instance
                                    .updateCurrentUserProfile(<String, dynamic>{
                                      'showPhotosToEveryone': value,
                                    });
                              },
                            ),
                          ],
                        ),

                        // ─── Advanced Settings ───
                        _SettingsSection(
                          title: "Advanced Settings",
                          icon: Icons.tune,
                          children: [
                            _SettingsActionRow(
                              label: "Saved Profiles",
                              subtitle: "Profiles you have bookmarked",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SavedProfilesPage(),
                                ),
                              ),
                            ),
                            _SettingsActionRow(
                              label: "Blocked Profiles",
                              subtitle: "Manage profiles you have blocked",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BlockedProfilesPage(),
                                ),
                              ),
                            ),
                            _SettingsActionRow(
                              label: "Ignored Profiles",
                              subtitle: "Profiles you didn't want to see again",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const IgnoredProfilesPage(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ─── Account Security (Linking) ───
                        _SettingsSection(
                          key: _securitySectionKey,
                          title: "Account Security",
                          icon: Icons.security_outlined,
                          children: [
                            _buildLinkingRow(
                              label: "Google Account",
                              providerId: "google.com",
                              onLink: _linkGoogle,
                            ),
                            _buildLinkingRow(
                              label: "Email & Password",
                              providerId: "password",
                              onLink: _linkEmailDialog,
                            ),
                          ],
                        ),

                        // ─── Help & Support ───
                        _SettingsSection(
                          title: "Help & Support",
                          icon: Icons.help_outline,
                          children: [
                            _SettingsActionRow(
                              label: "Terms of Service",
                              subtitle: "Read our rules and regulations",
                              onTap: () => _launchUrl("https://www.swan-match.com/terms"),
                            ),
                            _SettingsActionRow(
                              label: "Privacy Policy",
                              subtitle: "Learn how we protect your data",
                              onTap: () => _launchUrl("https://www.swan-match.com/privacy"),
                            ),
                            _SettingsActionRow(
                              label: "Community Guidelines",
                              subtitle: "Our standards for a safe space",
                              onTap: () => _launchUrl("https://www.swan-match.com/guidelines"),
                            ),
                            _SettingsActionRow(
                              label: "Subscription & Payments terms",
                              subtitle: "Manage your billing and payments",
                              onTap: () => _launchUrl("https://www.swan-match.com/subscription"),
                            ),
                            _SettingsActionRow(
                              label: "Safety Disclaimer",
                              subtitle: "Important safety information",
                              onTap: () => _launchUrl("https://www.swan-match.com/safety"),
                            ),
                            _SettingsActionRow(
                              label: "Data Deletion policy",
                              subtitle: "How to request data removal",
                              onTap: () => _launchUrl("https://www.swan-match.com/data-deletion"),
                            ),
                            _SettingsActionRow(
                              label: "Help & Contact",
                              subtitle: "Get in touch with support",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HelpSupportPage(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ─── Account Management ───
                        _SettingsSection(
                          title: "Account",
                          icon: Icons.manage_accounts_outlined,
                          children: [
                            _SettingsActionRow(
                              label: _isLoggingOut
                                  ? "Logging out..."
                                  : "Logout",
                              icon: Icons.logout,
                              isDestructive: true,
                              onTap: _isLoggingOut
                                  ? () {}
                                  : () async {
                                      setState(() => _isLoggingOut = true);
                                      try {
                                        await AuthService.instance.signOut();
                                        if (!context.mounted) return;
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CustomLoginPage(),
                                          ),
                                          (route) => false,
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AuthService.instance
                                                  .readableAuthError(error),
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isLoggingOut = false);
                                        }
                                      }
                                    },
                            ),
                            _SettingsActionRow(
                              label: _isDeletingAccount
                                  ? "Deleting account..."
                                  : "Delete Account",
                              icon: Icons.delete_outline,
                              isDestructive: true,
                              onTap: _isDeletingAccount
                                  ? () {}
                                  : () => _confirmAndDeleteAccount(profile),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        // Footer Links
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () => _launchUrl("https://www.swan-match.com/terms"),
                                child: const Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white38,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _launchUrl("https://www.swan-match.com/privacy"),
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            '© 2026 Swan Match, Inc. All Rights Reserved.',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '"Swan Match" and the gold Swan logo are registered trademarks.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white12,
                                fontSize: 9,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_isDeletingAccount)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppColors.obsidian.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 40,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: AppColors.onyx,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.goldMedium.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.goldMedium.withValues(alpha: 0.1),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.goldMedium,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Deleting Account",
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We are securely erasing your data.\nPlease do not close the app.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.5,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkingRow({
    required String label,
    required String providerId,
    required VoidCallback onLink,
  }) {
    final linkedProviders = AuthService.instance.getLinkedProviderIds();
    final isLinked = linkedProviders.contains(providerId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLinked ? "Verified & Linked" : "Not Linked",
                  style: TextStyle(
                    color: isLinked
                        ? AppColors.goldLight
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isLinked)
            TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.goldLight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                "Link Now",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Icon(
              Icons.check_circle,
              color: AppColors.goldLight,
              size: 20,
            ),
        ],
      ),
    );
  }
}

// ─── Sub-Components ──────────────────────────────────────────────────────────

// Glassmorphic Section Container
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.goldMedium, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(children: children),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;

  const _PasswordTextField({required this.controller, required this.hint});

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.goldMedium),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white38,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

// Clickable Row for Navigation (e.g. Change Password, Logout)
class _SettingsActionRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.label,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color itemColor = isDestructive ? Colors.redAccent.shade200 : Colors.white;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: itemColor.withValues(alpha: 0.8), size: 20),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: itemColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// Toggle Row (e.g. Push Notifications)
class _SettingsToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _SettingsToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.obsidian,
            activeTrackColor: AppColors.goldMedium,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Premium Dropdown Row (e.g. Mobile Visibility)
class _SettingsDropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String?) onChanged;

  const _SettingsDropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.onyx,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.goldMedium,
                  size: 20,
                ),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 13,
                ),
                items: options.map((String option) {
                  return DropdownMenuItem(value: option, child: Text(option));
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
