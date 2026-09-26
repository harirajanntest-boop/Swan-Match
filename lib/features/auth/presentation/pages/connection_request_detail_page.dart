import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/colors.dart';
import '../../../../models/connection_model.dart';
import '../../../../services/connection_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/helpers/deleted_user_helper.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'connection_accepted_page.dart';

/// Shown when a user taps a received PENDING connection request from the
/// Chat tab's Requests list. Lets the receiver watch the sender's topic
/// video response and accept / decline / report / block.
class ConnectionRequestDetailPage extends StatefulWidget {
  final ConnectionModel connection;

  const ConnectionRequestDetailPage({super.key, required this.connection});

  @override
  State<ConnectionRequestDetailPage> createState() =>
      _ConnectionRequestDetailPageState();
}

class _ConnectionRequestDetailPageState
    extends State<ConnectionRequestDetailPage> {
  static const List<Map<String, String>> _reportCategories = [
    {'label': '🚨 Harassment / Threats', 'value': 'harassment'},
    {'label': '👤 Fake Profile / Catfish', 'value': 'fake_profile'},
    {'label': '💰 Scam / Fraud', 'value': 'scam'},
    {'label': '🔞 Inappropriate Content', 'value': 'inappropriate'},
    {'label': '👶 Underage User', 'value': 'underage'},
    {'label': '📩 Spam / Solicitation', 'value': 'spam'},
    {'label': '📋 Other', 'value': 'other'},
  ];

  Map<String, dynamic>? _senderProfile;
  bool _loadingProfile = true;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  bool _isResponding = false;
  bool _isBlocking = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _loadSenderProfile();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadSenderProfile() async {
    try {
      final profile =
          await UserService.instance.getUserProfile(widget.connection.senderId);
      if (!mounted) return;
      setState(() {
        _senderProfile = profile;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _initVideo() async {
    final url = widget.connection.videoUrl;
    if (url.isEmpty) {
      if (mounted) setState(() => _videoError = true);
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      controller.addListener(_onVideoValueChanged);
      await controller.initialize();
      if (!mounted) {
        controller.removeListener(_onVideoValueChanged);
        controller.dispose();
        return;
      }
      if (controller.value.hasError) {
        controller.removeListener(_onVideoValueChanged);
        controller.dispose();
        setState(() => _videoError = true);
        return;
      }
      await controller.setLooping(true);
      setState(() {
        _videoController = controller;
        _videoInitialized = true;
      });
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _onVideoValueChanged() {
    if (!mounted) return;
    if (_videoController?.value.hasError == true && !_videoError) {
      setState(() => _videoError = true);
    }
  }

  bool get _senderDeleted => DeletedUserHelper.isDeleted(_senderProfile);

  String get _senderName {
    if (_senderProfile == null || _senderDeleted) {
      return DeletedUserHelper.getDisplayName(_senderProfile);
    }
    return (_senderProfile!['name'] ??
            _senderProfile!['firstName'] ??
            'User')
        .toString();
  }

  String? get _senderPhotoUrl => DeletedUserHelper.getAvatarUrl(_senderProfile);

  Future<void> _respond(bool accept) async {
    if (_isResponding || _reported) return;
    setState(() => _isResponding = true);
    try {
      await ConnectionService.instance.respondToConnection(
        connectionId: widget.connection.id,
        accept: accept,
      );
      if (!mounted) return;
      if (accept) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConnectionAcceptedPage(
              otherUserId: widget.connection.senderId,
              otherUserName: _senderName,
              otherUserPhotoUrl: _senderPhotoUrl ?? '',
            ),
          ),
        );
      } else {
        showLinearMessage(context, 'Request declined.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  String _readableError(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _showReportDialog() async {
    final reasonController = TextEditingController();
    String selectedCategory = '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Report Video',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report this video response for abuse? Our team will review it.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a category:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reportCategories.map((cat) {
                    final isSelected = selectedCategory == cat['value'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedCategory = cat['value']!;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent.withOpacity(0.15)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.white.withOpacity(0.12),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          cat['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.redAccent : Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Additional details (required):',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Please describe the issue...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );

    final reason = reasonController.text.trim();
    final chosenCategory = selectedCategory;
    reasonController.dispose();

    if (confirm != true) return;

    if (chosenCategory.isEmpty) {
      if (!mounted) return;
      showLinearMessage(context, 'Please select a report category.', isError: true);
      return;
    }
    if (reason.isEmpty) {
      if (!mounted) return;
      showLinearMessage(context, 'You must provide a reason to report.', isError: true);
      return;
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('reportConnectionVideo').call({
        'connectionId': widget.connection.id,
        'reason': reason,
        'category': chosenCategory,
      });
      if (!mounted) return;
      setState(() => _reported = true);
      showLinearMessage(context, 'Thanks — this video has been reported.');
    } catch (e) {
      if (!mounted) return;
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  Future<void> _showBlockDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Block Profile', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to block this profile?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBlocking = true);
    try {
      await UserService.instance.blockUser(widget.connection.senderId);
      if (!mounted) return;
      showLinearMessage(context, 'Profile blocked');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBlocking = false);
      showLinearMessage(context, _readableError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _loadingProfile ? 'Connection Request' : _senderName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSenderRow(),
                    const SizedBox(height: 20),
                    _buildTopic(),
                    const SizedBox(height: 20),
                    _buildVideo(),
                    if (_reported) ...[
                      const SizedBox(height: 20),
                      _buildReportedBanner(),
                    ],
                  ],
                ),
              ),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderRow() {
    final photoUrl = _senderPhotoUrl;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Container(
              color: const Color(0xFF1A1A1A),
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person,
                        color: AppColors.goldMedium.withOpacity(0.6),
                      ),
                    )
                  : Icon(Icons.person, color: AppColors.goldMedium.withOpacity(0.6)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _loadingProfile ? 'Loading…' : _senderName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopic() {
    if (widget.connection.topic.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldMedium.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldMedium.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESPONDING TO',
            style: TextStyle(
              color: AppColors.goldLight.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.connection.topic,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Thumbnail-first placeholder: shown instantly while the response video
  /// buffers, so viewers aren't staring at a bare spinner. Falls back to a
  /// plain dark placeholder (never a broken-image icon) when the thumbnail
  /// URL is missing/empty or fails to load.
  Widget _buildThumbnailLayer() {
    final thumbUrl = widget.connection.videoThumbnailUrl;
    if (thumbUrl.isEmpty) {
      return Container(color: const Color(0xFF141414));
    }
    return Image.network(
      thumbUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141414)),
    );
  }

  Widget _buildVideo() {
    final videoReady =
        _videoInitialized && _videoController != null && !_videoError;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: videoReady ? _videoController!.value.aspectRatio : 9 / 16,
        child: Container(
          color: const Color(0xFF141414),
          child: _videoError
              ? _buildVideoUnavailable()
              // Cross-fade from the instant thumbnail to the live video once
              // the controller has finished initializing.
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnailLayer(),
                    AnimatedOpacity(
                      opacity: videoReady ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: videoReady
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(_videoController!),
                                  if (!_videoController!.value.isPlaying)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVideoUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.white.withOpacity(0.35),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'This video is no longer available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Reported. Accept and Decline are disabled for this request.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final disabled = _isResponding || _isBlocking || _reported;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: disabled ? null : () => _respond(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: ElevatedButton(
                        onPressed: disabled ? null : () => _respond(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _isResponding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _reported ? null : _showReportDialog,
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: Colors.white.withOpacity(_reported ? 0.25 : 0.5),
                  ),
                  label: Text(
                    'Report',
                    style: TextStyle(color: Colors.white.withOpacity(_reported ? 0.25 : 0.5)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: (_isBlocking || _isResponding) ? null : _showBlockDialog,
                  icon: Icon(
                    Icons.block,
                    size: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  label: Text(
                    'Block',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
