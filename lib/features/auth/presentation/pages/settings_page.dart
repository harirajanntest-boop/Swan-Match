import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import 'onboarding_page.dart';
import 'help_center_page.dart';
import 'blocked_profiles_page.dart';
import 'ignored_profiles_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── State for Settings ───
  // Privacy
  String _mobileVisibility = 'All paid members';
  String _horoscopeVisibility = 'Visible to all';
  
  // Advanced
  String _callPreference = 'Call when there are important updates';
  bool _actionConfirmation = true;

  // Notifications
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _smsAlerts = false;
  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteAccount(Map<String, dynamic> profile) async {
    final registeredName = (profile['name'] ?? '').toString().trim();
    if (registeredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name is missing. Please update your profile first.')),
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
          title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
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
                style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final input = controller.text.trim().toLowerCase();
                final expected = registeredName.toLowerCase();
                Navigator.pop(dialogContext, input == expected);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name did not match. Account deletion cancelled.')),
      );
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await UserService.instance.deleteCurrentUserCompletely();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been permanently deleted.')),
      );
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'requires-recent-login'
          ? 'Please login again recently, then retry deleting your account.'
          : AuthService.instance.readableAuthError(error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete account right now. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.onyx,
            title: const Text('Change Password', style: TextStyle(color: Colors.white, fontFamily: 'serif')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PasswordTextField(controller: currentController, hint: 'Current Password'),
                  const SizedBox(height: 12),
                  _PasswordTextField(controller: newController, hint: 'New Password'),
                  const SizedBox(height: 12),
                  _PasswordTextField(controller: confirmController, hint: 'Confirm New Password'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final current = currentController.text.trim();
                  final newPass = newController.text.trim();
                  final confirm = confirmController.text.trim();

                  if (current.isEmpty || newPass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                    return;
                  }
                  if (newPass != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }

                  setDialogState(() => isLoading = true);
                  try {
                    await AuthService.instance.changePassword(current, newPass);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.instance.readableAuthError(e))));
                  } finally {
                    setDialogState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldMedium),
                child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldMedium, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
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
              final showProfileToEveryone = profile['showProfileToEveryone'] != false;
              final showPhotosToEveryone = profile['showPhotosToEveryone'] != false;
              
              final user = FirebaseAuth.instance.currentUser;
              final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
              final isPasswordUser = providers.contains('password');

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                
                // ─── Privacy Settings ───
                    _SettingsSection(
                      title: "Privacy Settings",
                      icon: Icons.lock_outline,
                      children: [
                        _SettingsDropdownRow(
                          label: "Show mobile number to",
                          value: _mobileVisibility,
                          options: const ['All paid members', 'Contacted / Responded to', 'Hide contact details'],
                          onChanged: (val) => setState(() => _mobileVisibility = val!),
                        ),
                        _SettingsDropdownRow(
                          label: "Who can view my horoscope",
                          value: _horoscopeVisibility,
                          options: const ['Visible to all', 'Contacted / Responded to', 'Protect horoscope'],
                          onChanged: (val) => setState(() => _horoscopeVisibility = val!),
                        ),
                        _SettingsToggleRow(
                          label: "Show Profile to Everyone",
                          subtitle: "Turn off to hide your profile from matches & recommendations.",
                          value: showProfileToEveryone,
                          onChanged: (value) async {
                            await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                              'showProfileToEveryone': value,
                            });
                          },
                        ),
                        _SettingsToggleRow(
                          label: "Show Photos to Everyone",
                          subtitle: "Turn off to hide your photos from public view.",
                          value: showPhotosToEveryone,
                          onChanged: (value) async {
                            await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                              'showPhotosToEveryone': value,
                            });
                          },
                          isLast: true,
                        ),
                      ],
                    ),

                    // ─── Advanced Settings ───
                    _SettingsSection(
                      title: "Advanced Settings",
                      icon: Icons.tune,
                      children: [
                        _SettingsDropdownRow(
                          label: "Call Preferences",
                          value: _callPreference,
                          options: const [
                            'Call when there are important updates',
                            'Call after 1 month',
                            'Call after 3 months',
                            'Never'
                          ],
                          onChanged: (val) => setState(() => _callPreference = val!),
                        ),
                        _SettingsToggleRow(
                          label: "Action Confirmation",
                          subtitle: "Confirm before sending an interest",
                          value: _actionConfirmation,
                          onChanged: (val) => setState(() => _actionConfirmation = val),
                        ),
                        _SettingsActionRow(
                          label: "Blocked Profiles",
                          subtitle: "Manage profiles you have blocked",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedProfilesPage())),
                        ),
                        _SettingsActionRow(
                          label: "Ignored Profiles",
                          subtitle: "Profiles you didn't want to see again",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IgnoredProfilesPage())),
                          isLast: true,
                        ),
                      ],
                    ),

                    // ─── Notifications ───
                    _SettingsSection(
                      title: "Notifications",
                      icon: Icons.notifications_outlined,
                      children: [
                        _SettingsToggleRow(
                          label: "Push Notifications",
                          subtitle: "Receive alerts on your device",
                          value: _pushNotifications,
                          onChanged: (val) => setState(() => _pushNotifications = val),
                        ),
                        _SettingsToggleRow(
                          label: "Email Alerts",
                          subtitle: "Receive matches & updates via email",
                          value: _emailAlerts,
                          onChanged: (val) => setState(() => _emailAlerts = val),
                        ),
                        _SettingsToggleRow(
                          label: "SMS Alerts",
                          subtitle: "Receive important updates via SMS",
                          value: _smsAlerts,
                          onChanged: (val) => setState(() => _smsAlerts = val),
                        ),
                      ],
                    ),

                    // ─── Help & Support ───
                    _SettingsSection(
                      title: "Help & Support",
                      icon: Icons.help_outline,
                      children: [
                        _SettingsActionRow(
                          label: "Help Us",
                          subtitle: "Visit our help desk & contact support",
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterPage())),
                        ),
                        _SettingsActionRow(
                          label: "About Swan Match",
                          subtitle: "Version 1.0.0",
                          isLast: true,
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Swan Match',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Icon(Icons.favorite, color: AppColors.goldMedium),
                              children: [
                                const Text("The premium matchmaking app for finding your perfect partner."),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    // ─── Account Management ───
                    _SettingsSection(
                      title: "Account",
                      icon: Icons.manage_accounts_outlined,
                      children: [
                        if (isPasswordUser)
                          _SettingsActionRow(
                            label: "Change Password",
                            icon: Icons.key_outlined,
                            onTap: () => _showChangePasswordDialog(),
                          ),
                        _SettingsActionRow(
                          label: _isLoggingOut ? "Logging out..." : "Logout",
                          icon: Icons.logout,
                          isDestructive: true,
                          onTap: _isLoggingOut
                              ? () {}
                              : () async {
                                  setState(() => _isLoggingOut = true);
                                  try {
                                    await AuthService.instance.signOut();
                                    if (!context.mounted) return;
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/login',
                                      (route) => false,
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AuthService.instance.readableAuthError(error),
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
                          label: _isDeletingAccount ? "Deleting account..." : "Delete Account",
                          icon: Icons.delete_outline,
                          isDestructive: true,
                          isLast: true,
                          onTap: _isDeletingAccount
                              ? () {}
                              : () => _confirmAndDeleteAccount(profile),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
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

  const _SettingsSection({required this.title, required this.icon, required this.children});

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
                  style: const TextStyle(color: AppColors.goldLight, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'serif', letterSpacing: 0.5),
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
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
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
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.goldMedium)),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
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
  final bool isLast;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.label,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
    this.isLast = false,
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
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: itemColor.withOpacity(0.8), size: 20),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: itemColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ]
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
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
  final bool isLast;

  const _SettingsToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.obsidian,
            activeTrackColor: AppColors.goldMedium,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
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
  final bool isLast;

  const _SettingsDropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.onyx,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.goldMedium, size: 20),
                style: const TextStyle(color: AppColors.goldLight, fontSize: 13),
                items: options.map((String option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
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