import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';

class DownloadBiodataPage extends StatefulWidget {
  const DownloadBiodataPage({super.key});

  @override
  State<DownloadBiodataPage> createState() => _DownloadBiodataPageState();
}

class _DownloadBiodataPageState extends State<DownloadBiodataPage> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final PageController _pageController;
  final GlobalKey _previewCaptureKey = GlobalKey();

  int _currentThemeIndex = 0;

  // ─── 5 Luxury Themes for the Biodata Header ───
  final List<Map<String, dynamic>> _themes = [
    {
      "name": "Emerald Traditional",
      "colors": [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
      "pattern": Icons.ac_unit, 
    },
    {
      "name": "Royal Sapphire",
      "colors": [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
      "pattern": Icons.diamond_outlined,
    },
    {
      "name": "Ruby Velvet",
      "colors": [const Color(0xFF880E4F), const Color(0xFFC2185B)],
      "pattern": Icons.favorite_border,
    },
    {
      "name": "Obsidian & Gold",
      "colors": [AppColors.obsidian, AppColors.onyx],
      "pattern": Icons.workspace_premium,
    },
    {
      "name": "Lavender Pearl",
      "colors": [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
      "pattern": Icons.flare,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);

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
    _pageController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _capturePreviewPng() async {
    final context = _previewCaptureKey.currentContext;
    if (context == null) return null;

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writePreviewFile(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/biodata_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _handleDownload() async {
    final bytes = await _capturePreviewPng();
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate biodata image right now.')),
      );
      return;
    }

    final file = await _writePreviewFile(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Biodata saved to ${file.path}')),
    );
  }

  Future<void> _handleShare() async {
    final bytes = await _capturePreviewPng();
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate biodata image right now.')),
      );
      return;
    }

    final file = await _writePreviewFile(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'My SWAN Match biodata',
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
          "Generate Biodata",
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

              return Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Swipe to select a theme",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _currentThemeIndex = index),
                      itemCount: _themes.length,
                      itemBuilder: (context, index) {
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              value = (1 - (value.abs() * 0.1)).clamp(0.0, 1.0);
                            }
                            return Center(
                              child: Transform.scale(
                                scale: value,
                                child: child,
                              ),
                            );
                          },
                          child: RepaintBoundary(
                            key: index == _currentThemeIndex ? _previewCaptureKey : null,
                            child: _BiodataPreviewCard(
                              theme: _themes[index],
                              profile: profile,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_themes.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentThemeIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentThemeIndex == index ? AppColors.goldMedium : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _themes[_currentThemeIndex]["name"],
                    style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Column(
                      children: [
                        GoldGradientButton(
                          text: "DOWNLOAD BIODATA",
                          onPressed: _handleDownload,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.goldMedium, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              foregroundColor: AppColors.goldMedium,
                            ),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text(
                              "SHARE BIODATA",
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            onPressed: _handleShare,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BiodataPreviewCard extends StatelessWidget {
  final Map<String, dynamic> theme;
  final Map<String, dynamic> profile;

  const _BiodataPreviewCard({required this.theme, required this.profile});

  String _read(String key, {String fallback = '-'}) {
    final value = profile[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dobWithAge() {
    final dob = _readDate(profile['dateOfBirth']);
    if (dob == null) return '-';
    final years = ((DateTime.now().difference(dob).inDays) / 365.25).floor();
    return '${DateFormat('d MMMM yyyy').format(dob)} ($years yrs)';
  }

  String _location() {
    final parts = [
      _read('city', fallback: ''),
      _read('state', fallback: ''),
      _read('country', fallback: ''),
    ].where((value) => value.isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  String _casteText() {
    final caste = _read('caste');
    final anyCaste = profile['anyCaste'] == true;
    if (caste == '-' && !anyCaste) return '-';
    if (anyCaste) {
      return caste == '-' ? 'Caste No Bar' : '$caste (Caste No Bar)';
    }
    return caste;
  }

  @override
  Widget build(BuildContext context) {
    bool isObsidian = theme["name"] == "Obsidian & Gold";
    List<Color> bgColors = theme["colors"];
    final name = _read('name');
    final initials = name == '-'
        ? 'U'
        : name
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isObsidian ? AppColors.onyx : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: bgColors.first.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: bgColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
                        itemBuilder: (context, i) => Icon(theme["pattern"], color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _BioRow(label: "Name", value: name, isDark: isObsidian),
                          _BioRow(label: "Height", value: _read('height'), isDark: isObsidian),
                          _BioRow(label: "Date of Birth", value: _dobWithAge(), isDark: isObsidian),
                          _BioRow(label: "Marital Status", value: _read('maritalStatus'), isDark: isObsidian),
                          _BioRow(label: "Religion", value: _read('religion'), isDark: isObsidian),
                          _BioRow(label: "Caste", value: _casteText(), isDark: isObsidian),
                          _BioRow(label: "Star", value: _read('star'), isDark: isObsidian),
                          _BioRow(label: "Location", value: _location(), isDark: isObsidian),
                          _BioRow(label: "Education", value: _read('educationDegree'), isDark: isObsidian),
                          _BioRow(label: "Occupation", value: _read('occupation'), isDark: isObsidian),
                          const SizedBox(height: 8),
                          Divider(color: isObsidian ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.goldMedium, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.qr_code_2, size: 50, color: Colors.black),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Powered By", style: TextStyle(color: isObsidian ? Colors.white54 : Colors.grey.shade600, fontSize: 10)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.favorite, color: Colors.white, size: 12),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            "matrimony.com",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: isObsidian ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -45,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isObsidian ? AppColors.onyx : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade300,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
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
    );
  }
}

class _BioRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _BioRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color labelColor = isDark ? Colors.white54 : Colors.grey.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
          ),
          Text(" :  ", style: TextStyle(color: labelColor, fontSize: 11)),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}