import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
          "Privacy Policy",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Privacy Policy of Swam Match",
                    style: TextStyle(color: AppColors.goldMedium, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "SwamMatch.com is an online matrimonial portal endeavouring constantly to provide you with premium matrimonial services. This privacy statement is common to all the matrimonial apps operated under Swam Match. Since we are strongly committed to your right to privacy, we have drawn out a privacy statement with regard to the information we collect from you.\n\nYou acknowledge that you are disclosing information voluntarily. By accessing/using the app and/or by providing your information, you consent to the collection and use of the info you disclose in accordance with this Privacy Policy.",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "What information do you need to give?",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "The information we gather from members and visitors who apply for the various services our App offers includes, but may not be limited to, photo of the user, your profile videos you wish to upload, email address, name, date of birth, educational qualifications, based on your explicitly consent identity proof documents which you voluntarily submit for verification purpose, a user-specified password, mailing address, zip/pin code and telephone/mobile number.\n\nWe use a secure server for credit card transactions to protect the credit card information of our users.",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}