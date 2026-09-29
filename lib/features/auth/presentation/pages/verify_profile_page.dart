import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/linear_message.dart';

class VerifyProfilePage extends StatefulWidget {
  const VerifyProfilePage({super.key});

  @override
  State<VerifyProfilePage> createState() => _VerifyProfilePageState();
}

class _VerifyProfilePageState extends State<VerifyProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final ImagePicker _picker = ImagePicker();
  File? _selfieFile;
  File? _idFile;
  bool _isSubmitting = false;

  bool _isVerified(Map<String, dynamic> profile) {
    return profile['isVerified'] == true ||
        profile['idVerified'] == true ||
        profile['profileVerified'] == true ||
        (profile['verificationStatus']?.toString().toLowerCase() == 'approved');
  }

  bool _reuploadEnabled(Map<String, dynamic> profile) {
    final value = profile['reuplaoded'];
    if (value == true) return true;
    if (value is String && value.trim().toLowerCase() == 'true') return true;
    return false;
  }

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
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _takeSelfie() async {
    if (_isSubmitting) return;
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
        preferredCameraDevice: CameraDevice.front,
      );
      if (photo != null && mounted) {
        setState(() => _selfieFile = File(photo.path));
      }
    } catch (_) {}
  }

  Future<void> _pickGovernmentId() async {
    if (_isSubmitting) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (image != null && mounted) {
        setState(() => _idFile = File(image.path));
      }
    } catch (_) {}
  }

  Future<void> _submitReupload() async {
    if (_isSubmitting) return;

    if (_selfieFile == null) {
      showLinearMessage(context, 'Please take a new selfie.', isError: true);
      return;
    }
    // Government ID is optional (Guideline 5.1.1v) — only the selfie is required.

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final selfieUrl = await StorageService.instance.uploadVerificationFile(
        uid: uid,
        file: _selfieFile!,
        kind: 'selfie',
      );
      final idFile = _idFile;
      final idUrl = idFile == null
          ? null
          : await StorageService.instance.uploadVerificationFile(
              uid: uid,
              file: idFile,
              kind: 'government_id',
            );

      // Storage PATHS, not public download URLs — only admins may open these
      // files (see StorageService.uploadVerificationFile). Old public links
      // from a previous submission are removed.
      await UserService.instance.updateCurrentUserProfile({
        'verificationPhotoPath': selfieUrl,
        'verificationPhotoUrl': FieldValue.delete(),
        if (idUrl != null) 'idVerificationPath': idUrl,
        if (idUrl != null) 'idVerificationUrl': FieldValue.delete(),
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
        'verificationStatus': 'pending',
        'profileApprovalStatus': 'pending',
        // isVerified is admin-only (firestore.rules blocks client writes to
        // it unconditionally) — clearing it on resubmission must happen via
        // the admin backend when it reviews the new submission, not here.
        'idVerified': false,
        'profileVerified': false,
        'reuplaoded': false,
      });

      if (!mounted) return;
      setState(() {
        _selfieFile = null;
        _idFile = null;
      });
      showLinearMessage(
        context,
        'Documents submitted. Our team will review them shortly.',
      );
    } catch (e) {
      if (mounted) {
        showLinearMessage(
          context,
          'Upload failed. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trust & Safety',
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: UserService.instance.watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final isVerified = _isVerified(profile);
          final showReupload = _reuploadEnabled(profile) && !isVerified;

          return FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _VerificationHero(isVerified: isVerified),
                    const SizedBox(height: 32),
                    const Text(
                      'Verify your profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Verification is handled by our Trust & Safety team. '
                      'Once approved, you will receive the Verified badge.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _TeamVerificationCard(
                      isVerified: isVerified,
                      submittedAt: profile['verificationSubmittedAt'],
                    ),
                    if (showReupload) ...[
                      const SizedBox(height: 28),
                      _ReuploadSection(
                        selfieFile: _selfieFile,
                        idFile: _idFile,
                        isSubmitting: _isSubmitting,
                        onTakeSelfie: _takeSelfie,
                        onPickId: _pickGovernmentId,
                        onSubmit: _submitReupload,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerificationHero extends StatelessWidget {
  final bool isVerified;

  const _VerificationHero({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.goldMedium.withOpacity(0.15),
                blurRadius: 50,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(65),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: AppColors.goldMedium.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isVerified ? Icons.verified : Icons.verified_user_outlined,
                color: isVerified ? Colors.greenAccent : AppColors.goldLight,
                size: 56,
              ),
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.obsidian,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 26,
              ),
            ),
          ),
      ],
    );
  }
}

class _TeamVerificationCard extends StatelessWidget {
  final bool isVerified;
  final dynamic submittedAt;

  const _TeamVerificationCard({
    required this.isVerified,
    required this.submittedAt,
  });

  String? _formattedSubmittedAt() {
    if (submittedAt == null) return null;
    try {
      DateTime? dt;
      if (submittedAt is Timestamp) {
        dt = submittedAt.toDate();
      } else if (submittedAt is DateTime) {
        dt = submittedAt;
      }
      if (dt == null) return null;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedLabel = _formattedSubmittedAt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _StatusChip(
            label: isVerified ? 'Status: Verified' : 'Status: Pending review',
            isPositive: isVerified,
          ),
          if (submittedLabel != null) ...[
            const SizedBox(height: 10),
            Text(
              'Submitted on $submittedLabel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;

  const _StatusChip({required this.label, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.greenAccent.withOpacity(0.15)
            : AppColors.goldMedium.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? Colors.greenAccent.withOpacity(0.6)
              : AppColors.goldMedium.withOpacity(0.6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPositive ? Colors.greenAccent : AppColors.goldMedium,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReuploadSection extends StatelessWidget {
  final File? selfieFile;
  final File? idFile;
  final bool isSubmitting;
  final VoidCallback onTakeSelfie;
  final VoidCallback onPickId;
  final VoidCallback onSubmit;

  const _ReuploadSection({
    required this.selfieFile,
    required this.idFile,
    required this.isSubmitting,
    required this.onTakeSelfie,
    required this.onPickId,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.goldMedium.withOpacity(0.06),
        border: Border.all(color: AppColors.goldMedium.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Re-upload verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our team requested new documents. Submit a fresh selfie. A government ID is optional.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _UploadTile(
            label: 'Selfie',
            subtitle: selfieFile != null ? 'Ready to upload' : 'Take a photo',
            icon: Icons.camera_alt_outlined,
            preview: selfieFile,
            onTap: isSubmitting ? null : onTakeSelfie,
          ),
          const SizedBox(height: 12),
          _UploadTile(
            label: 'Government ID (optional)',
            subtitle: idFile != null
                ? 'Ready to upload'
                : 'Optional — choose from gallery or skip',
            icon: Icons.badge_outlined,
            preview: idFile,
            onTap: isSubmitting ? null : onPickId,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldMedium,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Submit for review',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final File? preview;
  final VoidCallback? onTap;

  const _UploadTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: preview != null
                    ? Image.file(
                        preview!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: Colors.white.withOpacity(0.06),
                        child: Icon(icon, color: AppColors.goldMedium),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
