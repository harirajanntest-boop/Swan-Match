import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import 'main_dashboard.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  // Form State
  DateTime? _selectedDate;
  String _selectedGender = '';
  List<File> _selectedImages = [];
  bool _isLoading = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.goldMedium),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Complete Your Profile',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photos Section
              _buildPhotosSection(),
              const SizedBox(height: 30),
              
              // Name Field
              _buildTextField(
                label: 'Your name',
                hint: 'Enter your name',
                controller: _nameController,
              ),
              const SizedBox(height: 20),
              
              // Birthday Field
              _buildBirthdayField(),
              const SizedBox(height: 20),
              
              // Gender Field
              _buildGenderField(),
              const SizedBox(height: 20),
              
              // Bio Field
              _buildBioField(),
              const SizedBox(height: 40),
              
              // Continue Button
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add photos',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                // Add Photo Button
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.onyx,
                      border: Border.all(
                        color: AppColors.goldMedium,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          color: AppColors.goldMedium,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.goldMedium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Selected Image
              return Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_selectedImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: AppColors.onyx,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your b-day?',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.onyx,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.goldMedium),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppColors.goldMedium,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select your birthday',
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.white : Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.goldMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.onyx,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldMedium),
          ),
          child: Row(
            children: _genders.map((gender) {
              final isSelected = _selectedGender == gender;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = gender),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.goldMedium : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      gender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About me',
          style: TextStyle(
            color: AppColors.goldMedium,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bioController,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: AppColors.onyx,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.goldMedium, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldMedium,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty && _selectedImages.length < 6) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)).take(6 - _selectedImages.length));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 100 * 365)),
      lastDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images and get URLs
      List<String> imageUrls = [];
      for (File image in _selectedImages) {
        // TODO: Implement image upload to Firebase Storage
        // For now, use empty strings
        imageUrls.add('');
      }

      // Update user profile
      await UserService.instance.updateCurrentUserProfile({
        'name': _nameController.text.trim(),
        'dateOfBirth': _selectedDate!.toIso8601String(),
        'gender': _selectedGender,
        'photos': imageUrls,
        'bio': _bioController.text.trim(),
        'registrationCompleted': true,
        'completedOnboardingAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
