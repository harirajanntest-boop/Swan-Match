import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';
import 'verify_profile_page.dart';

class UserProfile {
  final String firstName;
  final int age;
  final String profession;
  final String city;
  final String country;
  final String photoUrl;
  final int completionPercent;
  final bool isVerified;
  final bool isGold;

  UserProfile({
    required this.firstName,
    required this.age,
    required this.profession,
    required this.city,
    required this.country,
    required this.photoUrl,
    required this.completionPercent,
    required this.isVerified,
    required this.isGold,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      firstName: map['firstName'] ?? '',
      age: map['age'] ?? 0,
      profession: map['profession'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      completionPercent: map['completionPercent'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      isGold: map['isGold'] ?? false,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  UserProfile? _userProfile;
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _userProfile = _mapToUserProfile(profile);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  UserProfile _mapToUserProfile(Map<String, dynamic> profile) {
    // Calculate profile completion
    final completionPercent = (_userService.calculateProfileCompletion(profile) * 100).toInt();
    
    // Get first photo URL
    String photoUrl = '';
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      photoUrl = photos[0].toString();
    }
    
    // Calculate age from dateOfBirth if available
    int age = 0;
    final dob = profile['dateOfBirth'];
    if (dob != null) {
      if (dob is DateTime) {
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
      } else if (dob.runtimeType.toString() == 'Timestamp') {
        try {
          final dobDate = (dob as dynamic).toDate() as DateTime;
          final now = DateTime.now();
          age = now.year - dobDate.year;
          if (now.month < dobDate.month || (now.month == dobDate.month && now.day < dobDate.day)) age--;
        } catch (_) {}
      }
    }
    // Fallback to age field if available
    if (age == 0) {
      age = (profile['age'] ?? 0) as int;
    }
    
    return UserProfile(
      firstName: (profile['name'] ?? profile['firstName'] ?? '').toString(),
      age: age,
      profession: (profile['occupation'] ?? profile['profession'] ?? '').toString(),
      city: (profile['city'] ?? '').toString(),
      country: (profile['country'] ?? '').toString(),
      photoUrl: photoUrl,
      completionPercent: completionPercent,
      isVerified: profile['isVerified'] == true,
      isGold: _userService.isPremium(profile),
    );
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    await _loadUserProfile();
  }

  String _getCompletionTip(int percent) {
    if (percent < 40) {
      return "Add more photos to increase your match rate by 60%.";
    } else if (percent < 60) {
      return "Add a voice prompt to increase your match rate by 40%.";
    } else if (percent < 80) {
      return "Complete your bio to get 30% more profile visits.";
    } else {
      return "Your profile looks great! Keep it updated.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),
            
            // Main Content
            Expanded(
              child: _isLoading || _userProfile == null
                  ? _buildShimmerLoading()
                  : RefreshIndicator(
                      color: const Color(0xFFD4A017),
                      onRefresh: _refreshProfile,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            // Profile Photo Section
                            _buildProfilePhotoSection(),
                            
                            const SizedBox(height: 24),
                            
                            // Profile Completion Card
                            _buildProfileCompletionCard(),
                            
                            const SizedBox(height: 28),
                            
                            // Get Verified Card
                            if (!_userProfile!.isVerified) _buildGetVerifiedCard(),
                            
                            const SizedBox(height: 28),
                            
                            // Swan Gold Section
                            _buildSwanGoldSection(),
                            
                            const SizedBox(height: 100), // Space for bottom nav
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // SWAN Text
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4A017),
              letterSpacing: 3,
            ),
          ),
          
          // Settings Icon
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFFD4A017),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Profile Photo
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4A017),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 68,
                  backgroundImage: _userProfile!.photoUrl.isNotEmpty
                      ? NetworkImage(_userProfile!.photoUrl)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: _userProfile!.photoUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              
              // Edit Button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4A017),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 14),
        
        // Name and Age
        Text(
          '${_userProfile!.firstName}, ${_userProfile!.age}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Profession and Location
        Text(
          '${_userProfile!.profession.toUpperCase()} • ${_userProfile!.city}, ${_userProfile!.country}',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white54,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCompletionCard() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Profile Completion',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4A017),
              ),
            ),
            Text(
              '${_userProfile!.completionPercent}%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD4A017),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: LinearProgressIndicator(
            value: _userProfile!.completionPercent / 100,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4A017)),
            minHeight: 8,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tip
        Text(
          _getCompletionTip(_userProfile!.completionPercent),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGetVerifiedCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VerifyProfilePage(),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Verified Icon
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2200),
              ),
              child: const Icon(
                Icons.verified,
                color: Color(0xFFD4A017),
                size: 28,
              ),
            ),
            
            const SizedBox(width: 14),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get verified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Prove you're the real you with a quick selfie.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            
            // Chevron
            const Icon(
              Icons.chevron_right,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwanGoldSection() {
    return Column(
      children: [
        const Text(
          'SWAN GOLD',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFFD4A017),
            letterSpacing: 2,
          ),
        ),
        
        const SizedBox(height: 8),
        
        const Text(
          'Elevate your experience to the private gallery level.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 20),
        
        // Upgrade Button or Active Status
        if (_userProfile!.isGold) ...[
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium,
                color: Color(0xFFD4A017),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Swan Gold Active',
                style: TextStyle(
                  color: Color(0xFFD4A017),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: () {
              // TODO: Implement subscription flow
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription feature coming soon!')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC8960C), Color(0xFFD4A017)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Upgrade to Swan Gold',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Shimmer for profile photo
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 14),
          // Shimmer for name
          Container(
            width: 150,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          // Shimmer for profession
          Container(
            width: 200,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          // Shimmer for completion card
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 28),
          // Shimmer for verified card
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 28),
          // Shimmer for gold section
          Container(
            width: 150,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
