import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';

/// Lightweight placeholder shown when the player taps a monetization lobby
/// icon while the real offer popup is still being wired. Replace the call
/// site with the matching offer popup once it's ready.
class ComingSoonPopup extends StatelessWidget {
  final String? offerName;
  const ComingSoonPopup({super.key, this.offerName});

  static Future<void> show(BuildContext context, {String? offerName}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => ComingSoonPopup(offerName: offerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = offerName?.isNotEmpty == true ? offerName! : 'Offer';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBlack.withValues(alpha: 0.96),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.6), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Coming soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
