import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/gold_button.dart';
import 'additional_details_page.dart';

class ProfessionalDetailsPage extends StatefulWidget {
  const ProfessionalDetailsPage({super.key});

  @override
  State<ProfessionalDetailsPage> createState() =>
      _ProfessionalDetailsPageState();
}

class _ProfessionalDetailsPageState extends State<ProfessionalDetailsPage>
    with SingleTickerProviderStateMixin {
  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Form State ────────────────────────────────────────────────────────────
  String? _selectedEducation;
  String? _selectedEmployment;
  String? _selectedOccupation;
  String _selectedCurrency = 'INR - India';
  String? _selectedIncome;

  // ─── Mock Data ─────────────────────────────────────────────────────────────
  final List<String> _educations = [
    'B.E. - Bachelor of Engineering',
    'B.Tech',
    'M.Tech',
    'MBA',
    'MBBS',
    'B.Sc',
    'M.Sc',
    'Ph.D',
  ];
  final List<String> _employments = [
    'Private',
    'Government',
    'Business',
    'Self Employed',
    'Not Working',
  ];
  final List<String> _currencies = [
    'INR - India',
    'USD - USA',
    'AED - UAE',
    'GBP - UK',
    'EUR - Europe',
  ];
  final List<String> _incomes = [
    '0 - 3 Lakhs',
    '3 - 5 Lakhs',
    '5 - 10 Lakhs',
    '10 - 20 Lakhs',
    '20+ Lakhs',
  ];

  // Categorized Occupations for the Search Modal
  final Map<String, List<String>> _occupationData = {
    'Hospitality': [
      'Hotel / Hospitality Professional',
      'Restaurant / Catering Professional',
      'Chef / Cook',
    ],
    'IT & Software': [
      'Software Professional',
      'Hardware Professional',
      'Product Manager',
      'Project Manager',
      'Program Manager',
      'Animator',
      'Cyber / Network Security',
      'UI / UX Designer',
      'Web / Graphic Designer',
      'Software Consultant',
      'Data Analyst',
    ],
    'Medicine': ['Doctor', 'Nurse', 'Pharmacist', 'Dentist'],
  };

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
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
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

  // ─── Custom Glassmorphic Search Modal ───
  void _showOccupationSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            String searchQuery = "";

            // Filter logic
            Map<String, List<String>> filteredData = {};
            _occupationData.forEach((category, jobs) {
              var matchingJobs = jobs
                  .where(
                    (job) =>
                        job.toLowerCase().contains(searchQuery.toLowerCase()),
                  )
                  .toList();
              if (matchingJobs.isNotEmpty ||
                  category.toLowerCase().contains(searchQuery.toLowerCase())) {
                filteredData[category] = matchingJobs.isEmpty
                    ? jobs
                    : matchingJobs;
              }
            });

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: AppColors.obsidian.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: AppColors.goldMedium.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      "Select your occupation",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.goldMedium.withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.goldMedium,
                          decoration: InputDecoration(
                            icon: const Icon(
                              Icons.search,
                              color: AppColors.goldMedium,
                            ),
                            hintText: "Search occupation",
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // List of Occupations
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          String category = filteredData.keys.elementAt(index);
                          List<String> jobs = filteredData[category]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                color: Colors.white.withOpacity(0.02),
                                child: Text(
                                  "-- $category --",
                                  style: TextStyle(
                                    color: AppColors.goldMedium.withOpacity(
                                      0.8,
                                    ),
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              ...jobs.map(
                                (job) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  title: Text(
                                    job,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() => _selectedOccupation = job);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Professional Details (4/5)",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            letterSpacing: 1,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── Progress Bar (Advanced to 80%) ───
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white.withOpacity(0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMedium.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Education ───
                      const _SectionTitle(title: "Your education degree"),
                      _PremiumDropdown(
                        hint: "Select degree",
                        value: _selectedEducation,
                        items: _educations,
                        onChanged: (v) =>
                            setState(() => _selectedEducation = v),
                      ),
                      const SizedBox(height: 24),

                      // ─── Employment Sector ───
                      const _SectionTitle(title: "Your employment sector"),
                      _PremiumDropdown(
                        hint: "Select sector",
                        value: _selectedEmployment,
                        items: _employments,
                        onChanged: (v) =>
                            setState(() => _selectedEmployment = v),
                      ),
                      const SizedBox(height: 24),

                      // ─── Occupation (Triggers Search Modal) ───
                      const _SectionTitle(title: "Select your occupation"),
                      GestureDetector(
                        onTap: _showOccupationSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedOccupation ?? "Search occupation",
                                style: TextStyle(
                                  color: _selectedOccupation == null
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              const Icon(
                                Icons.search,
                                color: AppColors.goldMedium,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Income Range ───
                      const _SectionTitle(title: "Your annual income"),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _PremiumDropdown(
                              hint: "Currency",
                              value: _selectedCurrency,
                              items: _currencies,
                              onChanged: (v) =>
                                  setState(() => _selectedCurrency = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: _PremiumDropdown(
                              hint: "Select income",
                              value: _selectedIncome,
                              items: _incomes,
                              onChanged: (v) =>
                                  setState(() => _selectedIncome = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // ─── Next Button ───
                      GoldGradientButton(
                        text: "NEXT",
                        onPressed: () async {
                          await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
                            'educationDegree': _selectedEducation ?? '',
                            'employmentSector': _selectedEmployment ?? '',
                            'occupation': _selectedOccupation ?? '',
                            'currency': _selectedCurrency,
                            'annualIncome': _selectedIncome ?? '',
                          });

                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdditionalDetailsPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ─── Footer Support ───
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Need help? Call ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                            const Icon(
                              Icons.phone,
                              color: AppColors.goldMedium,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "8144-99-88-77",
                              style: TextStyle(
                                color: AppColors.goldMedium,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable UI Components ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;

  const _PremiumDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.goldMedium,
            size: 18,
          ),
          dropdownColor: AppColors.onyx,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
