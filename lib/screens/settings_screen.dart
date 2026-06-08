import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/dev_tools_sheet.dart';
import '../services/ads/consent_manager.dart';
import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_buttons.dart';
import '../shared/widgets/app_top_bar.dart';

/// Hosted privacy policy. Surfaced from Settings → Privacy Policy and
/// referenced by the UMP consent form configured in the AdMob console.
const String _privacyPolicyUrl =
    'https://idanc1983-hub.github.io/skystrike-privacy/';

/// Settings — title-only top bar, two cards (audio toggles + Support IAP),
/// and a version footer that's hidden in release builds. Replaces the
/// older slider-heavy layout per the May 2026 redesign.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _vibration = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _musicEnabled = p.getBool('settings_music_enabled') ?? true;
      _sfxEnabled = p.getBool('settings_sfx_enabled') ?? true;
      _vibration = p.getBool('settings_vibration') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/Setting_screen.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x66000000)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppTopBar.titleOnly(
                  title: 'SETTINGS',
                  onClose: () => Navigator.of(context).pop(),
                  onTitleSecretHold:
                      kDebugMode ? () => DevToolsSheet.show(context) : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAudioCard(),
                        const SizedBox(height: 14),
                        _buildSupportCard(),
                        const SizedBox(height: 14),
                        _buildPrivacyCard(),
                      ],
                    ),
                  ),
                ),
                if (kDebugMode) _buildDebugFooter(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio + haptics card
  // ---------------------------------------------------------------------------
  Widget _buildAudioCard() {
    return _Card(
      child: Column(
        children: [
          _ToggleRow(
            label: 'Music',
            value: _musicEnabled,
            onChanged: (v) {
              setState(() => _musicEnabled = v);
              _saveBool('settings_music_enabled', v);
            },
          ),
          const _RowDivider(),
          _ToggleRow(
            label: 'Sound FX',
            value: _sfxEnabled,
            onChanged: (v) {
              setState(() => _sfxEnabled = v);
              _saveBool('settings_sfx_enabled', v);
            },
          ),
          const _RowDivider(),
          _ToggleRow(
            label: 'Vibration FX',
            value: _vibration,
            onChanged: (v) {
              setState(() => _vibration = v);
              _saveBool('settings_vibration', v);
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Support tip-jar card — always visible per redesign spec.
  // ---------------------------------------------------------------------------
  Widget _buildSupportCard() {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Support Sky Strike',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Love the game? A small contribution helps us keep building '
              'new worlds, jets and challenges.',
              style: TextStyle(
                color: Color(0xFFBDC9A8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            AppButton.primary(
              label: '\$4.99',
              height: 48,
              onPressed: _onSupportTap,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Privacy & account card — Privacy Policy link, conditional UMP
  // re-prompt, Restore Purchases (Apple requires the last one for any
  // app with non-consumable IAPs, e.g. Remove Ads).
  // ---------------------------------------------------------------------------
  Widget _buildPrivacyCard() {
    final showPrivacyChoices =
        ConsentManager.lastResult.isPrivacyOptionsRequired;
    return _Card(
      child: Column(
        children: [
          _NavRow(
            label: 'Privacy Policy',
            onTap: _onPrivacyPolicyTap,
          ),
          if (showPrivacyChoices) const _RowDivider(),
          if (showPrivacyChoices)
            _NavRow(
              label: 'Privacy Choices',
              onTap: _onPrivacyChoicesTap,
            ),
          const _RowDivider(),
          _NavRow(
            label: 'Restore Purchases',
            trailing: _restoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.amber),
                    ),
                  )
                : null,
            onTap: _restoring ? null : _onRestoreTap,
          ),
        ],
      ),
    );
  }

  Future<void> _onPrivacyPolicyTap() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open privacy policy: $e')),
      );
    }
  }

  Future<void> _onPrivacyChoicesTap() async {
    await ConsentManager.showPrivacyOptionsForm();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onRestoreTap() async {
    setState(() => _restoring = true);
    final economy = context.read<EconomyState>();
    String message;
    try {
      await economy.restorePurchases();
      message = 'Restore complete. Any prior purchases will reappear shortly.';
    } catch (e) {
      message = 'Restore failed: $e';
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF0d1f0d),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onSupportTap() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('support_ad_free', true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your support!'),
        backgroundColor: Color(0xFF0d1f0d),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Debug-only build footer. Hidden entirely in release builds. The dev
  // tools hook lives on a 5-second hold over the 'G' in the title.
  // ---------------------------------------------------------------------------
  Widget _buildDebugFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
      child: Text(
        'Sky Strike  V.1.0.0  Build  Debug',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.amber.withValues(alpha: 0.55),
          fontSize: 11,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card shell — dark fill, thin amber border, used for both cards.
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.amber.withValues(alpha: 0.18),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle row — label left, animated pill toggle right. OFF state shows an
// amber dot on a dark track to match the mock.
// ---------------------------------------------------------------------------
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _Toggle(value: value),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable nav row — label left, chevron (or spinner) right. Used by the
// Privacy & account card.
// ---------------------------------------------------------------------------
class _NavRow extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _NavRow({
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.white60 : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: AppColors.amber.withValues(alpha: 0.65),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  const _Toggle({required this.value});

  @override
  Widget build(BuildContext context) {
    final trackColor =
        value ? AppColors.green : AppColors.surfaceBlack;
    final borderColor =
        value ? AppColors.greenLight : AppColors.amber.withValues(alpha: 0.6);
    final knobColor = value ? Colors.white : AppColors.amber;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 48,
      height: 26,
      decoration: BoxDecoration(
        color: trackColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: knobColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
