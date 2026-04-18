import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/gold_button.dart';

class RateUsDialog extends StatefulWidget {
  const RateUsDialog({super.key});

  @override
  State<RateUsDialog> createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<RateUsDialog> {
  int _currentRating = 0;

  // Map rating to emojis
  String get _emoji {
    switch (_currentThemeRating()) {
      case 1: return "😠";
      case 2: return "🙁";
      case 3: return "😐";
      case 4: return "🙂";
      case 5: return "😍";
      default: return "😶";
    }
  }
  
  int _currentThemeRating() => _currentRating == 0 ? 3 : _currentRating;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.obsidian.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.goldMedium.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Right Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.white.withOpacity(0.5), size: 20),
                  ),
                ),
                
                const Text(
                  "How is your experience while using our app?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                ),
                const SizedBox(height: 12),
                Text(
                  "Rate us to let us know how we are doing!",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Animated Emoji
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    _emoji,
                    key: ValueKey<int>(_currentRating),
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 32),

                // Interactive Stars
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: List.generate(5, (index) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _currentRating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          index < _currentRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: index < _currentRating ? AppColors.goldMedium : Colors.white.withOpacity(0.2),
                          size: 34,
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 32),
                
                // Submit Button
                GoldGradientButton(
                  text: "Submit Rating",
                  onPressed: _currentRating > 0 ? () {
                    Navigator.pop(context);
                    // Add logic to save rating here
                  } : () {}, // Disabled if no rating selected
                ),
                
                const SizedBox(height: 20),
                Text(
                  "P.S. A five star makes our day better!",
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}