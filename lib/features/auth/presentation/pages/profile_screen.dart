import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/trial_service.dart';
import 'settings_page.dart';
import 'custom_login_page.dart';
import 'edit_profile_page.dart';
import 'verify_profile_page.dart';
import 'subscription_page.dart';
import 'about_me_screen.dart';
import 'values_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile is streamed — no async load needed.
  // Stream reuses the active Firestore listener so opens after the first are instant.

  bool _isLoggingOut = false;
  Timer? _trialCheckTimer;

  @override
  void initState() {
    super.initState();
    // Periodically check if trial has expired so we update UI immediately
    _trialCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null && mounted) {
          await TrialService.checkTrialStatus(uid);
          // The stream will automatically update when Firestore changes
        }
      },
    );
  }

  @override
  void dispose() {
    _trialCheckTimer?.cancel();
    super.dispose();
  }

  // ─── Helpers (take profile as parameter so they work with stream data) ───
  String _name(Map<String, dynamic> p) =>
      (p['name'] ?? p['firstName'] ?? '').toString();

  int _age(Map<String, dynamic> p) {
    final dob = p['dateOfBirth'];
    if (dob == null) return (p['age'] ?? 0) as int;
    try {
      final d = (dob as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      int a = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
      return a;
    } catch (_) {
      return (p['age'] ?? 0) as int;
    }
  }

  String _location(Map<String, dynamic> p) {
    final city = (p['city'] ?? '').toString().trim();
    final country = (p['country'] ?? '').toString().trim();
    return [city, country].where((s) => s.isNotEmpty).join(', ');
  }

  String _photoUrl(Map<String, dynamic> p) {
    final photos = p['photos'] ?? p['images'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    final pic = (p['profilePicture'] ??
            p['photoUrl'] ??
            p['profilePic'] ??
            '')
        .toString()
        .trim();
    return pic;
  }

  int _photoCount(Map<String, dynamic> p) {
    final photos = p['photos'];
    return (photos is List) ? photos.length : 0;
  }

  /// A user is considered verified ONLY when an admin has approved their ID.
  /// Checking `isVerified` (admin field), `profileVerified`, or `verificationStatus == 'approved'`.
  bool _isVerified(Map<String, dynamic> p) =>
      p['isVerified'] == true ||
      p['idVerified'] == true ||
      p['profileVerified'] == true ||
      (p['verificationStatus']?.toString().toLowerCase() == 'approved');

  bool _isPremium(Map<String, dynamic> p) => UserService.instance.isPremium(p);
  bool _isOnFreeTrial(Map<String, dynamic> p) => UserService.instance.isOnFreeTrial(p);
  bool _isPaidPremium(Map<String, dynamic> p) => UserService.instance.isPaidPremium(p);

  int? _trialDaysLeft(Map<String, dynamic> p) {
    final t = p['freeTrialEndsAt'];
    if (t == null) return null;
    try {
      final end = (t as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      final diff = end.difference(now);
      if (diff.inSeconds < 0) return 0;
      return diff.inDays + 1;
    } catch (_) {
      return null;
    }
  }

  // ─── Logout ───
  Future<void> _logout() async {
    if (_isLoggingOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoggingOut = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomLoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.instance.readableAuthError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
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

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: UserService.instance.watchCurrentUserProfile(),
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.goldMedium),
              );
            }
            final profile = snapshot.data ?? const <String, dynamic>{};
            return Column(
              children: [
                // ─── Avatar with edit overlay ───
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.goldMedium,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMedium.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _photoUrl(profile).isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _photoUrl(profile),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: const Color(0xFF1A1A1A)),
                                  errorWidget: (_, __, ___) => _noPhoto(),
                                )
                              : _noPhoto(),
                        ),
                      ),
                      // ─── Pencil edit icon ───
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfilePage(),
                            ),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.goldMedium,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0A0A0A),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ─── Name + verified ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _age(profile) > 0
                          ? '${_name(profile)}, ${_age(profile)}'
                          : _name(profile),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_isVerified(profile)) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: AppColors.goldMedium,
                        size: 20,
                      ),
                    ],
                    // Show exactly one account badge: trial takes precedence over premium
                    Builder(builder: (_) {
                      final days = _trialDaysLeft(profile) ?? 0;
                      if (days > 0) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'TRIAL ${days}d',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      if (_isPremium(profile)) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE2B859), Color(0xFFC79836)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.goldMedium.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.black87, size: 10),
                                  SizedBox(width: 2),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    }),
                  ],
                ),

                const SizedBox(height: 4),

                // ─── Location ───
                Text(
                  _location(profile),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Menu items (expanded to fill remaining space) ───
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        label: 'About Me',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutMeScreen(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.edit_outlined,
                        label: 'Edit Profile',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.favorite_border_rounded,
                        label: 'Values',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ValuesScreen(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.verified_outlined,
                        label: 'Verification',
                        trailing: _isVerified(profile)
                            ? 'Verified ✓'
                            : (profile['verificationStatus']?.toString().toLowerCase() == 'pending'
                                ? 'Pending Review'
                                : 'Get Verified'),
                        trailingColor: _isVerified(profile)
                            ? AppColors.goldMedium
                            : (profile['verificationStatus']?.toString().toLowerCase() == 'pending'
                                ? Colors.orangeAccent
                                : Colors.white38),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerifyProfilePage(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.settings_outlined,
                        label: 'Account Settings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Subscription',
                        trailing: _isPaidPremium(profile)
                            ? 'Premium'
                            : (_isOnFreeTrial(profile) ? 'Free Trial' : 'Upgrade'),
                        trailingColor: AppColors.goldMedium,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionPage(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        iconColor: Colors.redAccent.withOpacity(0.8),
                        labelColor: Colors.redAccent.withOpacity(0.9),
                        onTap: _logout,
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
                              child: const Text('Terms of Service', style: TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white38)),
                            ),
                            TextButton(
                              onPressed: () => _launchUrl("https://www.swan-match.com/privacy"),
                              child: const Text('Privacy Policy', style: TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white38)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _noPhoto() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white24, size: 52),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── MENU ITEM ROW ────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Color? trailingColor;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingColor,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.goldMedium.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white60, size: 26),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: TextStyle(
                  color: trailingColor ?? Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
