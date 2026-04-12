import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'privacy_policy_page.dart';

class SafeSwamMatchPage extends StatelessWidget {
  const SafeSwamMatchPage({super.key});

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
          "Safe Swan Match",
          style: TextStyle(color: Colors.white, fontFamily: 'serif', letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Why Safe Swan Match?",
              style: TextStyle(color: AppColors.goldMedium, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
            ),
            const SizedBox(height: 12),
            Text(
              "Safe Swan Match is our initiative to guide you to a safe online matrimony service. You can trust us with your information and credentials. We are always there to support you in case of privacy abuse.",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildWarningCard(
              icon: Icons.person_search_outlined, iconColor: Colors.orangeAccent, title: "HOW TO IDENTIFY FRAUDSTERS?", onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildWarningCard(
              icon: Icons.block_outlined, iconColor: Colors.redAccent, title: "REPORT PROFILE", onTap: () {},
            ),
            const SizedBox(height: 40),
            const Text("CONTACT US", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            Text(
              "To report fraud, contact our Fraud Assistance team immediately. Your information will be kept confidential.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildContactMethod(icon: Icons.phone_in_talk, title: "Call us", value: "0-893-945-5547")),
                Expanded(child: _buildContactMethod(icon: Icons.email_outlined, title: "Write to us", value: "reportfraud@\nswanmatch.com")),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: () {
                  // FIXED: Removed the "const" keyword here
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyPolicyPage()));
                },
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                    children: [
                      TextSpan(text: "Click here ", style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
                      TextSpan(text: "to view our Privacy Policy"),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard({required IconData icon, required Color iconColor, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethod({required IconData icon, required String title, required String value}) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldMedium), child: Icon(icon, color: AppColors.obsidian, size: 24)),
        const SizedBox(height: 12), Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4), Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}