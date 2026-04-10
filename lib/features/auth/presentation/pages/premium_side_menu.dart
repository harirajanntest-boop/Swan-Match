import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';

// Import our pages
import 'edit_profile_page.dart';
import 'edit_preferences_page.dart';
import 'download_biodata_page.dart';
import 'settings_page.dart';
import 'privacy_policy_page.dart';
import 'safe_swam_match_page.dart';
import 'verify_profile_page.dart'; 
import 'success_stories_page.dart';
import 'rate_us_dialog.dart';
import 'main_dashboard.dart';

class PremiumSideMenu extends StatelessWidget {
  const PremiumSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.obsidian,
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.goldMedium),
            );
          }

          final profile = snapshot.data ?? <String, dynamic>{};
          final name = (profile['name'] ?? '').toString().trim().isEmpty
              ? 'Member'
              : profile['name'].toString();
          final uid = (profile['uid'] ?? '').toString();
          final profileImageUrl = [
            profile['photoUrl'],
            profile['profileImageUrl'],
            profile['imageUrl'],
          ]
              .map((value) => (value ?? '').toString().trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
          final memberId = uid.isEmpty ? 'Member ID N/A' : 'M${uid.substring(0, uid.length > 8 ? 8 : uid.length).toUpperCase()}';
          final subscription = (profile['subscriptionPlan'] ?? 'free').toString();
          final memberType = subscription == 'free' ? 'Free Member' : 'Premium Member';

          return Column(
            children: [
          // ─── Custom Header ───
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.onyx, AppColors.obsidian],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: profileImageUrl.isEmpty
                              ? Container(
                                  color: AppColors.obsidian,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.goldMedium,
                                    size: 30,
                                  ),
                                )
                              : Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: AppColors.obsidian,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.goldMedium,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.obsidian,
                                      child: const Icon(
                                        Icons.person,
                                        color: AppColors.goldMedium,
                                        size: 30,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            memberId,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            memberType,
                            style: TextStyle(
                              color: AppColors.goldMedium,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Upgrade Banner in Menu ───
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldDark.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Upgrade membership to call or message with matches",
                          style: TextStyle(
                            color: AppColors.obsidian,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainDashboard(initialIndex: 4),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.obsidian,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Upgrade now",
                            style: TextStyle(
                              color: AppColors.goldMedium,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Menu Items ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildDivider(),

                  _buildMenuItem(
                    Icons.edit_outlined,
                    "Edit profile",
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.tune_outlined,
                    "Edit preferences",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditPreferencesPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.verified_user_outlined,
                    "Verify your profile",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VerifyProfilePage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.download_outlined,
                    "Download biodata",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadBiodataPage(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),

                  _buildSectionHeader("Support & feedback"),
                  _buildMenuItem(
                    Icons.settings_outlined,
                    "Settings",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.logout,
                    "Logout",
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await AuthService.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to logout right now. Please try again.')),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    Icons.help_outline,
                    "Help",
                    trailing: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
_buildMenuItem(
                    Icons.star_border, 
                    "Rate us",
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      showDialog(
                        context: context,
                        builder: (context) => const RateUsDialog(),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.groups_outlined, 
                    "Success stories",
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SuccessStoriesPage()),
                      );
                    },
                  ),                  
                  // ─── The Expandable "More" Dropdown ───
                  const _ExpandableMoreMenu(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
          );
        },
      ),
    );
  }

  // ─── Helper Functions ───
  Widget _buildMenuItem(
    IconData icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: AppColors.goldMedium, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: onTap, 
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }
}

// ─── Stateful Widget for the "More" Dropdown ───
class _ExpandableMoreMenu extends StatefulWidget {
  const _ExpandableMoreMenu();

  @override
  State<_ExpandableMoreMenu> createState() => _ExpandableMoreMenuState();
}

class _ExpandableMoreMenuState extends State<_ExpandableMoreMenu> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The "More" Button
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          leading: const Icon(Icons.add_circle_outline, color: AppColors.goldMedium, size: 22),
          title: const Text("More", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
          ),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
        
        // The Dropdown Content
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: Container(
            height: _isExpanded ? null : 0,
            padding: const EdgeInsets.only(left: 60, right: 24, bottom: 8), // Indented so it looks like a sub-menu
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text("Privacy policy", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text("Safe Swam Match", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SafeSwamMatchPage()));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}