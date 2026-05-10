import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../economy/ui/ace_settings_tile.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _cGreen      = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale  = Color(0xFFC0DD97);
const _cGreenMid   = Color(0xFF639922);
const _cGreenDark  = Color(0xFF173404);
const _cCard       = Color(0xEB0D1A0D); // rgba(13,26,13,0.92)
const _cBorder     = Color(0xFF1e3d1e);
const _cDivider    = Color(0xFF1a2a1a);
const _cAmber      = Color(0xFFEF9F27);
const _cAmberDark  = Color(0xFF854F0B);
const _cAmberLight = Color(0xFFFAC775);
const _cAmberMuted = Color(0xFF633806);

// ─── Languages ────────────────────────────────────────────────────────────────
const _languages = [
  ('English', 'en'), ('Hebrew', 'he'), ('Spanish', 'es'), ('French', 'fr'),
  ('German', 'de'), ('Japanese', 'ja'), ('Chinese', 'zh'), ('Portuguese', 'pt'),
  ('Russian', 'ru'), ('Arabic', 'ar'),
];

// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Audio
  bool   _musicEnabled   = true;
  double _musicVolume    = 0.8;
  bool   _sfxEnabled     = true;
  double _sfxVolume      = 1.0;
  bool   _vibration      = false;
  // Display
  String _language       = 'en';
  bool   _showFps        = false;
  // Game
  bool   _autoSkipTimer  = false;
  bool   _leftHand       = false;
  // Support
  bool   _thankyouFlash  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _musicEnabled  = p.getBool('settings_music_enabled')  ?? true;
      _musicVolume   = p.getDouble('settings_music_volume') ?? 0.8;
      _sfxEnabled    = p.getBool('settings_sfx_enabled')    ?? true;
      _sfxVolume     = p.getDouble('settings_sfx_volume')   ?? 1.0;
      _vibration     = p.getBool('settings_vibration')      ?? false;
      _language      = p.getString('settings_language')     ?? 'en';
      _showFps       = p.getBool('settings_show_fps')       ?? false;
      _autoSkipTimer = p.getBool('settings_autoskip_timer') ?? false;
      _leftHand      = p.getBool('settings_left_hand')      ?? false;
    });
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) fn) async {
    final p = await SharedPreferences.getInstance();
    await fn(p);
  }

  void _set<T>(T val, String key, void Function(T) setter) {
    setState(() => setter(val));
    if (val is bool)   _save((p) => p.setBool(key, val));
    if (val is double) _save((p) => p.setDouble(key, val));
    if (val is String) _save((p) => p.setString(key, val));
  }

  String get _languageLabel =>
      _languages.firstWhere((l) => l.$2 == _language, orElse: () => _languages.first).$1;

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0d1f0d),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: _cBorder, width: 0.5),
      ),
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: _cGreen, borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('SELECT LANGUAGE',
                style: TextStyle(color: _cGreenLight, fontSize: 13,
                    fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _languages.map((lang) {
                  final selected = _language == lang.$2;
                  return GestureDetector(
                    onTap: () {
                      setSheet(() {});
                      _set(lang.$2, 'settings_language', (v) => _language = v);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(lang.$1,
                                style: const TextStyle(
                                    color: _cGreenPale, fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected ? _cGreen : _cGreenMid,
                                  width: 1.5),
                              color: selected ? _cGreen : Colors.transparent,
                            ),
                            child: selected
                                ? const Center(
                                    child: CircleAvatar(
                                        radius: 3,
                                        backgroundColor: _cGreenPale))
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d1a0d),
                    border: Border.all(color: _cGreen, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Done',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _cGreenLight, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _onSupportTap() {
    setState(() => _thankyouFlash = true);
    _save((p) => p.setBool('support_ad_free', true));
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _thankyouFlash = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Thank you for your support! ♥'),
      backgroundColor: Color(0xFF0d1f0d),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0a1a0a)),
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/Setting_screen.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('AUDIO'),
                        const SizedBox(height: 6),
                        _buildAudioCard(),
                        const SizedBox(height: 14),

                        _sectionLabel('DISPLAY'),
                        const SizedBox(height: 6),
                        _buildDisplayCard(),
                        const SizedBox(height: 14),

                        _sectionLabel('GAME'),
                        const SizedBox(height: 6),
                        _buildGameCard(),
                        const SizedBox(height: 8),
                        const AceSettingsTile(),
                        const SizedBox(height: 14),

                        _sectionLabel('SUPPORT'),
                        const SizedBox(height: 6),
                        _buildSupportPanel(),
                        const SizedBox(height: 16),

                        _buildFooterLinks(),
                        const SizedBox(height: 10),
                        _buildVersionString(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _cGreenPale, letterSpacing: 3,
            ),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: _cDivider),
      ],
    );
  }

  // ─── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text,
          style: const TextStyle(
              color: _cGreenMid, fontSize: 9,
              letterSpacing: 2.5, fontWeight: FontWeight.w600)),
    );
  }

  // ─── Card wrapper ──────────────────────────────────────────────────────────
  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        border: Border.all(color: _cBorder, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 0.5, thickness: 0.5,
                  indent: 14, endIndent: 14, color: _cDivider),
          ],
        ],
      ),
    );
  }

  // ─── Toggle widget ─────────────────────────────────────────────────────────
  Widget _toggle(bool value, ValueChanged<bool> onChange) {
    return GestureDetector(
      onTap: () => onChange(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 24,
        decoration: BoxDecoration(
          color: value ? _cGreen : _cGreenDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? _cGreenLight : _cGreenMid, width: 0.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? _cGreenPale : _cGreenMid,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Standard row: label + subtitle + right control ────────────────────────
  Widget _row({
    required String title,
    String? subtitle,
    required Widget control,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _cGreenPale, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _cGreenMid, fontSize: 10)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            control,
          ],
        ),
      ),
    );
  }

  // ─── Slider + toggle row ───────────────────────────────────────────────────
  Widget _sliderRow({
    required String title,
    required bool enabled,
    required double volume,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSlider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: _cGreenPale, fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Opacity(
            opacity: enabled ? 1.0 : 0.3,
            child: SizedBox(
              width: 90,
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: _cGreen,
                  inactiveTrackColor: _cBorder,
                  thumbColor: _cGreenLight,
                  overlayColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: volume,
                  onChanged: enabled ? onSlider : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _toggle(enabled, onToggle),
        ],
      ),
    );
  }

  // ─── AUDIO card ────────────────────────────────────────────────────────────
  Widget _buildAudioCard() {
    return _card([
      _sliderRow(
        title: 'Music',
        enabled: _musicEnabled,
        volume: _musicVolume,
        onToggle: (v) => _set(v, 'settings_music_enabled', (x) => _musicEnabled = x),
        onSlider: (v) => _set(v, 'settings_music_volume',  (x) => _musicVolume  = x),
      ),
      _sliderRow(
        title: 'Sound FX',
        enabled: _sfxEnabled,
        volume: _sfxVolume,
        onToggle: (v) => _set(v, 'settings_sfx_enabled', (x) => _sfxEnabled = x),
        onSlider: (v) => _set(v, 'settings_sfx_volume',  (x) => _sfxVolume  = x),
      ),
      _row(
        title: 'Vibration',
        control: _toggle(_vibration,
            (v) => _set(v, 'settings_vibration', (x) => _vibration = x)),
      ),
    ]);
  }

  // ─── DISPLAY card ──────────────────────────────────────────────────────────
  Widget _buildDisplayCard() {
    return _card([
      _row(
        title: 'Language',
        subtitle: _languageLabel,
        control: const Icon(Icons.chevron_right, color: _cGreenMid, size: 20),
        onTap: _showLanguagePicker,
      ),
      _row(
        title: 'Show FPS',
        control: _toggle(_showFps,
            (v) => _set(v, 'settings_show_fps', (x) => _showFps = x)),
      ),
    ]);
  }

  // ─── GAME card ─────────────────────────────────────────────────────────────
  Widget _buildGameCard() {
    return _card([
      _row(
        title: 'Auto-skip Timer',
        subtitle: 'Show countdown on wave complete',
        control: _toggle(_autoSkipTimer,
            (v) => _set(v, 'settings_autoskip_timer', (x) => _autoSkipTimer = x)),
      ),
      _row(
        title: 'Left-Hand Mode',
        subtitle: 'Flip controls layout',
        control: _toggle(_leftHand,
            (v) => _set(v, 'settings_left_hand', (x) => _leftHand = x)),
      ),
    ]);
  }

  // ─── SUPPORT panel ─────────────────────────────────────────────────────────
  Widget _buildSupportPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF412402).withValues(alpha: 0.35),
        border: Border.all(color: _cAmberDark, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF854F0B).withValues(alpha: 0.3),
                  border: Border.all(color: _cAmberDark, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, color: _cAmberDark, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Support Sky Strike',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Love the game? A small contribution helps us keep building new worlds, jets, and challenges.',
            style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _onSupportTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _cAmberDark,
                border: Border.all(color: _cAmber, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('\$4.99',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _cAmber, fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: _thankyouFlash ? _cAmber : _cAmberMuted,
                fontSize: 10,
              ),
              child: const Text('Thank you'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer links ──────────────────────────────────────────────────────────
  Widget _buildFooterLinks() {
    Widget footerBtn(String label, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0d1a0d).withValues(alpha: 0.7),
              border: Border.all(color: _cBorder, width: 0.5),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _cGreenMid, fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg),
            backgroundColor: const Color(0xFF0d1f0d),
            behavior: SnackBarBehavior.floating));

    return Row(
      children: [
        footerBtn('Privacy', () => snack('Opening Privacy Policy…')),
        const SizedBox(width: 8),
        footerBtn('Terms',   () => snack('Opening Terms of Use…')),
        const SizedBox(width: 8),
        footerBtn('Restore', () => snack('Restoring purchases…')),
      ],
    );
  }

  // ─── Version string ────────────────────────────────────────────────────────
  Widget _buildVersionString() {
    return const Center(
      child: Text(
        'SKY STRIKE v1.0.0 · Build 1',
        style: TextStyle(
            color: Color(0xFF27500A), fontSize: 9, letterSpacing: 1.2),
      ),
    );
  }
}
