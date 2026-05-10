import 'dart:async';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cGreenDark = Color(0xFF173404);
const _cGreenDarker = Color(0xFF27500A);
const _cGreenTrack = Color(0xFF0d1f0d);
const _cAmber = Color(0xFFEF9F27);
const _cAmberDark = Color(0xFF854F0B);
const _cAmberLight = Color(0xFFFAC775);
const _cGemBg = Color(0xFF412402);
const _cPurpleDark = Color(0xFF3C3489);
const _cPurpleLight = Color(0xFF7F77DD);
const _cPurplePale = Color(0xFFCECBF6);

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
class _JetData {
  final String id;
  final String name;
  final double speed;
  final double attack;
  final double hp;
  final int? coinPrice;
  final int? gemPrice;
  final bool isHot;

  const _JetData({
    required this.id,
    required this.name,
    required this.speed,
    required this.attack,
    required this.hp,
    this.coinPrice,
    this.gemPrice,
    this.isHot = false,
  });
}

const _standardJets = <_JetData>[
  _JetData(id: 'viper', name: 'Viper', speed: 0.60, attack: 0.50, hp: 0.70),
  _JetData(
      id: 'inferno',
      name: 'Inferno',
      speed: 0.75,
      attack: 0.85,
      hp: 0.60,
      coinPrice: 1200,
      isHot: true),
  _JetData(
      id: 'specter',
      name: 'Specter',
      speed: 0.90,
      attack: 0.45,
      hp: 0.55,
      coinPrice: 900),
  _JetData(
      id: 'phantom',
      name: 'Phantom',
      speed: 0.80,
      attack: 0.80,
      hp: 0.80,
      coinPrice: 2500),
];

const _wraith = _JetData(
  id: 'wraith_x',
  name: 'Wraith X',
  speed: 1.0,
  attack: 1.0,
  hp: 0.95,
  gemPrice: 300,
);

class _ChestData {
  final String id;
  final String name;
  final String guaranteed;
  final String bonusChance;
  final int coinPrice;

  const _ChestData({
    required this.id,
    required this.name,
    required this.guaranteed,
    required this.bonusChance,
    required this.coinPrice,
  });
}

const _standardChests = <_ChestData>[
  _ChestData(
      id: 'basic',
      name: 'Basic',
      guaranteed: 'Coins + power-up',
      bonusChance: 'Rare jet',
      coinPrice: 200),
  _ChestData(
      id: 'rare',
      name: 'Rare',
      guaranteed: '2× coins + booster',
      bonusChance: 'Epic jet skin',
      coinPrice: 600),
  _ChestData(
      id: 'epic',
      name: 'Epic',
      guaranteed: 'Epic jet + gem bonus',
      bonusChance: 'Exclusive skin',
      coinPrice: 1500),
];

class _PuData {
  final String id;
  final String name;
  final String description;
  final int coinPrice;

  const _PuData({
    required this.id,
    required this.name,
    required this.description,
    required this.coinPrice,
  });
}

const _powerUps = <_PuData>[
  _PuData(
      id: 'shield',
      name: 'Shield Burst',
      description: 'Absorbs 1 hit · lasts 1 wave',
      coinPrice: 150),
  _PuData(
      id: 'rapidfire',
      name: 'Rapid Fire',
      description: '3× bullet rate · 20 seconds',
      coinPrice: 200),
  _PuData(
      id: 'speed',
      name: 'Speed Surge',
      description: '2× movement · 15 seconds',
      coinPrice: 120),
  _PuData(
      id: 'bomb',
      name: 'Bomb Drop',
      description: 'Clears all enemies on screen',
      coinPrice: 350),
  _PuData(
      id: 'hp',
      name: 'HP Pack',
      description: 'Restores 1 HP mid-wave',
      coinPrice: 80),
];

class _DealData {
  final String item;
  final String type;
  final int originalPrice;
  final int price;
  final int discount;
  final String? assetId;

  const _DealData({
    required this.item,
    required this.type,
    required this.originalPrice,
    required this.price,
    required this.discount,
    this.assetId,
  });
}

const _dailyDeals = <_DealData>[
  _DealData(
      item: 'Inferno Jet',
      type: 'jet',
      assetId: 'inferno',
      originalPrice: 1200,
      price: 720,
      discount: 40),
  _DealData(
      item: 'Speed Surge ×5',
      type: 'powerup',
      originalPrice: 600,
      price: 420,
      discount: 30),
];

class _IapPack {
  final String price;
  final int amount;
  final String? bonus;
  final bool isHighlight;
  final bool isBestValue;

  const _IapPack({
    required this.price,
    required this.amount,
    this.bonus,
    this.isHighlight = false,
    this.isBestValue = false,
  });
}

const _gemPacks = <_IapPack>[
  _IapPack(price: '\$1.99', amount: 80),
  _IapPack(price: '\$5.99', amount: 250),
  _IapPack(price: '\$9.99', amount: 500),
  _IapPack(price: '\$19.99', amount: 1100, bonus: '+10%'),
  _IapPack(price: '\$49.99', amount: 3000, bonus: '+20%', isHighlight: true),
  _IapPack(price: '\$99.99', amount: 7000, bonus: '+40%', isHighlight: true, isBestValue: true),
];

const _coinPacks = <_IapPack>[
  _IapPack(price: '\$1.99', amount: 1000),
  _IapPack(price: '\$5.99', amount: 3500),
  _IapPack(price: '\$9.99', amount: 6500),
  _IapPack(price: '\$19.99', amount: 15000, bonus: '+15%'),
  _IapPack(price: '\$49.99', amount: 42000, bonus: '+25%', isHighlight: true),
  _IapPack(price: '\$99.99', amount: 100000, bonus: '+40%', isHighlight: true, isBestValue: true),
];

class _DayReward {
  final int coins;
  final int gems;
  final String? powerUp;

  const _DayReward({required this.coins, this.gems = 0, this.powerUp});
}

const _dayRewards = <_DayReward>[
  _DayReward(coins: 100, powerUp: '1× HP Pack'),
  _DayReward(coins: 150, gems: 5),
  _DayReward(coins: 200, powerUp: '1× Speed Surge'),
  _DayReward(coins: 250, gems: 5, powerUp: '1× Rapid Fire'),
  _DayReward(coins: 300, gems: 10, powerUp: '1× Speed Surge'),
  _DayReward(coins: 400, gems: 10, powerUp: '1× Bomb Drop'),
  _DayReward(coins: 500, gems: 15, powerUp: '1× Rare Chest'),
];

// ---------------------------------------------------------------------------
// ShopScreen
// ---------------------------------------------------------------------------
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // Mock state
  final int _level = 14;
  final int _currentWorld = 1;
  int _coins = 4200;
  int _gems = 80;
  final Set<String> _ownedJets = {'viper'};
  final Map<String, int> _powerUpCounts = {
    'shield': 3,
    'rapidfire': 1,
    'speed': 0,
    'bomb': 2,
    'hp': 5,
  };
  int _storedRevives = 0;
  final int _currentStreak = 4;
  int _longestStreak = 12;
  bool _giftClaimed = false;

  int _activeTab = 0;

  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_updateCountdown);
    });
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day + 1);
    _timeUntilReset = midnight.difference(now);
    if (_timeUntilReset.isNegative) _timeUntilReset = Duration.zero;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Today is Day 5 (streak = 4 days done, today is unclaimed Day 5)
  int get _todayDay => (_currentStreak % 7) + 1;

  String get _countdownHms {
    final h = _timeUntilReset.inHours.toString().padLeft(2, '0');
    final m = (_timeUntilReset.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_timeUntilReset.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _countdownHm {
    final h = _timeUntilReset.inHours;
    final m = _timeUntilReset.inMinutes % 60;
    return '${h}h ${m}m';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF0d1f0d),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _claimGift() {
    if (_giftClaimed) return;
    final dayIndex = (_todayDay - 1).clamp(0, _dayRewards.length - 1);
    final reward = _dayRewards[dayIndex];
    setState(() {
      _giftClaimed = true;
      _coins += reward.coins;
      _gems += reward.gems;
      if (_todayDay > _longestStreak) _longestStreak = _todayDay;
    });
  }

  String _formatCoins(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _coinRow(int amount, {double iconSize = 12, double fontSize = 10, Color textColor = _cGreenPale}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/ui/icon_coin.png', width: iconSize, height: iconSize),
        const SizedBox(width: 3),
        Text(
          _formatCoins(amount),
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backgrounds/shop_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              _buildTabRow(),
              const SizedBox(height: 8),
              Expanded(
                child: IndexedStack(
                  index: _activeTab,
                  children: [
                    _buildDealsTab(),
                    _buildJetsTab(),
                    _buildChestsTab(),
                    _buildPowerUpsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _chip('Lv $_level',
              bg: _cGreenDark, opacity: 0.85, textColor: _cGreenLight),
          const Spacer(),
          _iconChip(
              asset: 'assets/ui/icon_coin.png',
              value: _formatCoins(_coins),
              bg: _cGreenDark,
              textColor: _cGreenPale),
          const SizedBox(width: 6),
          _iconChip(
              asset: 'assets/ui/icon_gem.png',
              value: '$_gems',
              bg: _cGemBg,
              textColor: _cAmber),
        ],
      ),
    );
  }

  Widget _chip(String text,
      {required Color bg, required double opacity, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _iconChip({
    required String asset,
    required String value,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab row
  // ---------------------------------------------------------------------------
  Widget _buildTabRow() {
    const labels = ['Deals', 'Jets', 'Chests', 'Power-Ups'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0a1a0a),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final isActive = i == _activeTab;
            BorderRadius? radius;
            if (i == 0) {
              radius = const BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              );
            } else if (i == 3) {
              radius = const BorderRadius.only(
                topRight: Radius.circular(7),
                bottomRight: Radius.circular(7),
              );
            }
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? _cGreen : Colors.transparent,
                    borderRadius: radius,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? _cGreenPale : _cGreenMid,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (i == 0 && !_giftClaimed)
                        Positioned(
                          top: 0,
                          right: 8,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: _cAmber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------
  Widget _buildHintBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF173404).withValues(alpha: 0.6),
        border: Border.all(color: _cGreen, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(color: _cGreenLight, fontSize: 10)),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _cAmberDark,
        fontSize: 9,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _statBar(String label, double fraction) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(label,
              style: const TextStyle(color: _cGreenMid, fontSize: 9)),
        ),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: _cGreenTrack,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _biomeChestAsset {
    const map = {
      1: 'assets/ui/icon_chest_biome_jungle.png',
      2: 'assets/ui/icon_chest_biome_ocean.png',
      3: 'assets/ui/icon_chest_biome_desert.png',
      4: 'assets/ui/icon_chest_biome_volcano.png',
      5: 'assets/ui/icon_chest_biome_arctic.png',
      6: 'assets/ui/icon_chest_biome_city.png',
    };
    return map[_currentWorld] ?? 'assets/ui/icon_chest_biome_jungle.png';
  }

  // ---------------------------------------------------------------------------
  // JETS TAB
  // ---------------------------------------------------------------------------
  Widget _buildJetsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintBanner('★ Jets are purchased with Coins'),
          const SizedBox(height: 10),
          _sectionLabel('STANDARD'),
          const SizedBox(height: 6),
          for (int i = 0; i < _standardJets.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildJetCard(_standardJets[i])),
                const SizedBox(width: 8),
                if (i + 1 < _standardJets.length)
                  Expanded(child: _buildJetCard(_standardJets[i + 1]))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          _sectionLabel('GEM-EXCLUSIVE'),
          const SizedBox(height: 6),
          _buildWraithXCard(),
          const SizedBox(height: 12),
          _buildRemoveAdsRow(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildJetCard(_JetData jet) {
    final owned = _ownedJets.contains(jet.id);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
        border: Border.all(color: _cGreen, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jet.isHot)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _cAmberDark,
                  border: Border.all(color: _cAmber, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('HOT',
                    style: TextStyle(
                        color: _cAmberLight,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.asset(
                'assets/jets/jet_${jet.id}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    CustomPaint(painter: _JetSvgPainter(jet.id)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(jet.name,
              style: const TextStyle(
                  color: _cGreenPale,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _statBar('Spd', jet.speed),
          const SizedBox(height: 3),
          _statBar('Atk', jet.attack),
          const SizedBox(height: 3),
          _statBar('HP', jet.hp),
          const SizedBox(height: 8),
          _buildJetButton(jet, owned),
        ],
      ),
    );
  }

  Widget _buildJetButton(_JetData jet, bool owned) {
    if (owned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1a2a1a),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Owned',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _cGreenMid,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
    }

    if (jet.gemPrice != null) {
      return GestureDetector(
        onTap: () {
          if (_gems < jet.gemPrice!) {
            _showSnackBar('Not enough gems');
            return;
          }
          setState(() {
            _gems -= jet.gemPrice!;
            _ownedJets.add(jet.id);
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _cGemBg,
            border: Border.all(color: _cAmber, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('💎 ${jet.gemPrice}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _cAmberLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_coins < (jet.coinPrice ?? 0)) {
          _showSnackBar('Not enough coins');
          return;
        }
        setState(() {
          _coins -= jet.coinPrice!;
          _ownedJets.add(jet.id);
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: _cGreen,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: _coinRow(jet.coinPrice!, iconSize: 13, fontSize: 11)),
      ),
    );
  }

  Widget _buildWraithXCard() {
    final owned = _ownedJets.contains(_wraith.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0a1a).withValues(alpha: 0.95),
        border: Border.all(color: _cPurpleLight, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/jets/jet_${_wraith.id}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  CustomPaint(painter: _JetSvgPainter(_wraith.id)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Wraith X',
                        style: TextStyle(
                            color: _cPurplePale,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cPurpleDark,
                        border: Border.all(color: _cPurpleLight, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Exclusive',
                          style: TextStyle(
                              color: _cPurplePale,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _statBar('Spd', _wraith.speed),
                const SizedBox(height: 3),
                _statBar('Atk', _wraith.attack),
                const SizedBox(height: 3),
                _statBar('HP', _wraith.hp),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (owned)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2a1a),
                border: Border.all(color: _cGreen, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Owned',
                  style: TextStyle(
                      color: _cGreenMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            )
          else
            GestureDetector(
              onTap: () {
                if (_gems < _wraith.gemPrice!) {
                  _showSnackBar('Not enough gems');
                  return;
                }
                setState(() {
                  _gems -= _wraith.gemPrice!;
                  _ownedJets.add(_wraith.id);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _cGemBg,
                  border: Border.all(color: _cAmber, width: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('💎 ${_wraith.gemPrice}',
                    style: const TextStyle(
                        color: _cAmberLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoveAdsRow() {
    return GestureDetector(
      onTap: () => _showSnackBar('Opening purchase flow…'),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF173404).withValues(alpha: 0.5),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remove Ads',
                    style: TextStyle(
                        color: _cGreenPale,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('One-time · No more interruptions',
                    style: TextStyle(color: _cGreenMid, fontSize: 9)),
              ],
            ),
            Text('\$2.99',
                style: TextStyle(
                    color: _cGreenLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHESTS TAB
  // ---------------------------------------------------------------------------
  Widget _buildChestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintBanner(
              '★ Most chests use Coins · Special chests use Gems'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _standardChests.map((c) {
              final isLast = c == _standardChests.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 6),
                  child: _buildChestCard(c),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _buildGemChestRow(
            title: 'Operation Chest',
            subtitle:
                'Guaranteed Epic jet + 3× gem bonus + exclusive skin',
            gemPrice: 50,
            badge: 'Best',
            borderColor: _cAmber,
            imagePath: 'assets/ui/icon_chest_operation.png',
          ),
          const SizedBox(height: 8),
          _buildGemChestRow(
            title: 'Biome Chest',
            subtitle: 'Biome-themed skin + random rare jet',
            gemPrice: 25,
            badge: 'New',
            borderColor: _cGreen,
            imagePath: _biomeChestAsset,
          ),
        ],
      ),
    );
  }

  Widget _buildChestCard(_ChestData chest) {
    return GestureDetector(
      onTap: () {
        if (_coins < chest.coinPrice) {
          _showSnackBar('Not enough coins');
          return;
        }
        setState(() => _coins -= chest.coinPrice);
        _showSnackBar('${chest.name} Chest opened!');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                'assets/ui/icon_chest_${chest.id}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    _ChestPlaceholder(id: chest.id),
              ),
            ),
            const SizedBox(height: 6),
            Text(chest.name,
                style: const TextStyle(
                    color: _cGreenPale,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(chest.guaranteed,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: _cGreenMid, fontSize: 8)),
            const SizedBox(height: 6),
            GestureDetector(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: _cGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: _coinRow(chest.coinPrice)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGemChestRow({
    required String title,
    required String subtitle,
    required int gemPrice,
    required String badge,
    required Color borderColor,
    String? imagePath,
  }) {
    return GestureDetector(
      onTap: () {
        if (_gems < gemPrice) {
          _showSnackBar('Not enough gems');
          return;
        }
        setState(() => _gems -= gemPrice);
        _showSnackBar('$title opened!');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: imagePath != null
                  ? Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const _GemChestPlaceholder(),
                    )
                  : const _GemChestPlaceholder(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(
                                color: _cGreenPale,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _cAmberDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                color: _cAmberLight,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _cGreenMid, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _cGemBg,
                border: Border.all(color: _cAmber, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('💎 $gemPrice',
                  style: const TextStyle(
                      color: _cAmberLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POWER-UPS TAB
  // ---------------------------------------------------------------------------
  Widget _buildPowerUpsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        children: [
          for (final pu in _powerUps) ...[
            _buildPowerUpRow(pu),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 7),
          _buildRevivePackCard(),
        ],
      ),
    );
  }

  Widget _buildPowerUpRow(_PuData pu) {
    final count = _powerUpCounts[pu.id] ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
        border: Border.all(color: _cGreenDarker, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Image.asset(
              'assets/ui/pu_${pu.id}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _PuPlaceholder(id: pu.id),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pu.name,
                    style: const TextStyle(
                        color: _cGreenPale,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(pu.description,
                    style:
                        const TextStyle(color: _cGreenMid, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('×$count',
              style: const TextStyle(
                  color: _cGreenMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (_coins < pu.coinPrice) {
                _showSnackBar('Not enough coins');
                return;
              }
              setState(() {
                _coins -= pu.coinPrice;
                _powerUpCounts[pu.id] = count + 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _cGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _coinRow(pu.coinPrice),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevivePackCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF412402).withValues(alpha: 0.3),
        border: Border.all(color: _cAmberDark, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revive Pack · 5× Revives',
              style: TextStyle(
                  color: _cAmberLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              'Save gems — buy in bulk vs. single revive during gameplay'
              '${_storedRevives > 0 ? ' · Stored: $_storedRevives' : ''}',
              style: const TextStyle(color: _cAmberDark, fontSize: 9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Single revive: 💎 5–20 in-game',
                  style: TextStyle(color: _cAmberDark, fontSize: 9)),
              GestureDetector(
                onTap: () {
                  if (_gems < 35) {
                    _showSnackBar('Not enough gems');
                    return;
                  }
                  setState(() {
                    _gems -= 35;
                    _storedRevives += 5;
                  });
                  _showSnackBar('+5 revives added');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _cGemBg,
                    border: Border.all(color: _cAmber, width: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('💎 35 · Save 25%',
                      style: TextStyle(
                          color: _cAmberLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEALS TAB
  // ---------------------------------------------------------------------------
  Widget _buildDealsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountdownBanner(),
          const SizedBox(height: 12),
          _buildStreakBar(),
          const SizedBox(height: 8),
          _buildGiftCard(),
          const SizedBox(height: 10),
          _buildStreakCalendar(),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Best streak: $_longestStreak days',
              style: const TextStyle(color: _cGreenMid, fontSize: 10),
            ),
          ),
          const SizedBox(height: 16),
          _buildGemPacksSection(),
          const SizedBox(height: 14),
          _buildCoinPacksSection(),
          const SizedBox(height: 16),
          _sectionLabel('DAILY DEALS'),
          const SizedBox(height: 6),
          _buildDealCard(_dailyDeals[0], isHot: true),
          const SizedBox(height: 8),
          _buildDealCard(_dailyDeals[1], isHot: false),
          const SizedBox(height: 12),
          _buildTomorrowTeaser(),
        ],
      ),
    );
  }

  Widget _buildGemPacksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GEMS'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF412402).withValues(alpha: 0.15),
            border: Border.all(color: _cGemBg, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '💎 Premium currency · Revives, exclusive jets & chests',
            style: TextStyle(color: _cAmberDark, fontSize: 10),
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: List.generate(_gemPacks.length, (i) =>
              _buildIapPackCard(_gemPacks[i], index: i + 1, isGem: true)),
        ),
      ],
    );
  }

  Widget _buildCoinPacksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('COINS'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF173404).withValues(alpha: 0.3),
            border: Border.all(color: _cGreenDarker, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '★ Main currency · Earn in gameplay or buy packs below',
            style: TextStyle(color: _cGreenMid, fontSize: 10),
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: List.generate(_coinPacks.length, (i) =>
              _buildIapPackCard(_coinPacks[i], index: i + 1, isGem: false)),
        ),
      ],
    );
  }

  Widget _buildIapPackCard(_IapPack pack,
      {required int index, required bool isGem}) {
    final borderColor = pack.isHighlight
        ? (isGem ? _cAmber : _cGreenLight)
        : (isGem ? _cGemBg : _cGreenDarker);
    final btnBg = isGem ? _cGemBg : _cGreen;
    final btnBorder = isGem ? _cAmber : null;
    final btnText = isGem ? _cAmberLight : _cGreenPale;
    final packAsset =
        'assets/ui/${isGem ? 'gems' : 'coins'}_$index.png';

    return GestureDetector(
      onTap: () => _showSnackBar('Opening purchase flow…'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  packAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  isGem ? 'assets/ui/icon_gem.png' : 'assets/ui/icon_coin.png',
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 3),
                Text(
                  _formatCoins(pack.amount),
                  style: TextStyle(
                    color: isGem ? _cAmberLight : _cGreenPale,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: btnBg,
                border: btnBorder != null
                    ? Border.all(color: btnBorder, width: 0.5)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                pack.price,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: btnText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF412402).withValues(alpha: 0.35),
        border: Border.all(color: _cAmberDark, width: 0.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deals reset in',
                  style: TextStyle(color: _cAmberDark, fontSize: 9)),
              SizedBox(height: 2),
              Text('New gift & deals every 24h',
                  style: TextStyle(color: _cAmberDark, fontSize: 8)),
            ],
          ),
          Text(
            _countdownHms,
            style: const TextStyle(
              color: _cAmber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBar() {
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final done = day < _todayDay ||
            (day == _todayDay && _giftClaimed);
        final isToday = day == _todayDay && !_giftClaimed;
        final Color fill;
        if (done) {
          fill = _cGreen;
        } else if (isToday) {
          fill = _cAmber;
        } else {
          fill = _cGreenTrack;
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 6 ? 3 : 0),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGiftCard() {
    final dayIndex = (_todayDay - 1).clamp(0, _dayRewards.length - 1);
    final reward = _dayRewards[dayIndex];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
        border: Border.all(color: _cGreen, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/ui/icon_chest.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const _GiftChestPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day $_todayDay Gift',
                    style: const TextStyle(
                        color: _cGreenPale,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _coinRow(reward.coins, iconSize: 11, textColor: _cGreenMid),
                if (reward.gems > 0)
                  Text('💎 ${reward.gems}',
                      style: const TextStyle(
                          color: _cGreenMid, fontSize: 9)),
                if (reward.powerUp != null)
                  Text(reward.powerUp!,
                      style: const TextStyle(
                          color: _cGreenMid, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _giftClaimed ? null : _claimGift,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _giftClaimed ? _cGreenDark : _cGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _giftClaimed ? 'Claimed' : 'Claim',
                style: TextStyle(
                  color: _giftClaimed ? _cGreenMid : _cGreenPale,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar() {
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final done = day < _todayDay ||
            (day == _todayDay && _giftClaimed);
        final isToday = day == _todayDay && !_giftClaimed;
        final Color bg;
        if (done) {
          bg = _cGreen;
        } else if (isToday) {
          bg = _cAmber;
        } else {
          bg = _cGreenTrack;
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: bg,
                border: day == 7
                    ? Border.all(color: _cAmberDark, width: 1)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                done ? '✓' : '$day',
                style: TextStyle(
                  color: (done || isToday)
                      ? Colors.black
                      : _cGreenMid,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDealCard(_DealData deal, {required bool isHot}) {
    return GestureDetector(
      onTap: () {
        if (_coins < deal.price) {
          _showSnackBar('Not enough coins');
          return;
        }
        setState(() => _coins -= deal.price);
        _showSnackBar('${deal.item} purchased!');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(
              color: isHot ? _cAmber : _cGreenDarker, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: deal.type == 'jet' && deal.assetId != null
                  ? Image.asset(
                      'assets/jets/jet_${deal.assetId}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          CustomPaint(painter: _JetSvgPainter(deal.assetId!)),
                    )
                  : const _PuPlaceholder(id: 'speed'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.item,
                      style: const TextStyle(
                          color: _cGreenPale,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/ui/icon_coin.png', width: 12, height: 12,
                              color: _cGreenMid, colorBlendMode: BlendMode.modulate),
                          const SizedBox(width: 3),
                          Text(
                            _formatCoins(deal.originalPrice),
                            style: const TextStyle(
                              color: _cGreenMid,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _cGreenMid,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      _coinRow(deal.price, iconSize: 14, fontSize: 13),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isHot ? _cAmberDark : _cGreenDarker,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${deal.discount}%',
                    style: TextStyle(
                      color: isHot ? _cAmberLight : _cGreenLight,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _cGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Buy',
                      style: TextStyle(
                          color: _cGreenPale,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTomorrowTeaser() {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time,
                color: _cGreenMid, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tomorrow's deals are locked",
                    style:
                        TextStyle(color: _cGreenMid, fontSize: 11)),
                const SizedBox(height: 2),
                Text(_countdownHm,
                    style: const TextStyle(
                        color: _cAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jet SVG painters — distinct shape per jet ID
// ---------------------------------------------------------------------------
class _JetSvgPainter extends CustomPainter {
  final String id;
  const _JetSvgPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    switch (id) {
      case 'viper':
        _paintViper(canvas, size);
      case 'inferno':
        _paintInferno(canvas, size);
      case 'specter':
        _paintSpecter(canvas, size);
      case 'phantom':
        _paintPhantom(canvas, size);
      case 'wraith_x':
        _paintWraithX(canvas, size);
      default:
        _paintViper(canvas, size);
    }
  }

  void _paintViper(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B6D11)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.92, h * 0.58)
      ..lineTo(w * 0.65, h * 0.70)
      ..lineTo(w * 0.60, h)
      ..lineTo(w * 0.5, h * 0.82)
      ..lineTo(w * 0.40, h)
      ..lineTo(w * 0.35, h * 0.70)
      ..lineTo(w * 0.08, h * 0.58)
      ..lineTo(w * 0.38, h * 0.42)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF97C459)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }

  void _paintInferno(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBF4A00)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.68, h * 0.38)
      ..lineTo(w, h * 0.60)
      ..lineTo(w * 0.72, h * 0.72)
      ..lineTo(w * 0.62, h)
      ..lineTo(w * 0.5, h * 0.80)
      ..lineTo(w * 0.38, h)
      ..lineTo(w * 0.28, h * 0.72)
      ..lineTo(0, h * 0.60)
      ..lineTo(w * 0.32, h * 0.38)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFEF9F27)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  void _paintSpecter(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4a6a7a)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.56, h * 0.35)
      ..lineTo(w, h * 0.52)
      ..lineTo(w * 0.9, h * 0.62)
      ..lineTo(w * 0.58, h * 0.56)
      ..lineTo(w * 0.60, h)
      ..lineTo(w * 0.5, h * 0.88)
      ..lineTo(w * 0.40, h)
      ..lineTo(w * 0.42, h * 0.56)
      ..lineTo(w * 0.1, h * 0.62)
      ..lineTo(0, h * 0.52)
      ..lineTo(w * 0.44, h * 0.35)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF90b8c8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }

  void _paintPhantom(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2a2a4a)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.64, h * 0.45)
      ..lineTo(w * 0.95, h * 0.55)
      ..lineTo(w * 0.70, h * 0.68)
      ..lineTo(w * 0.64, h * 0.88)
      ..lineTo(w * 0.58, h * 0.75)
      ..lineTo(w * 0.5, h * 0.80)
      ..lineTo(w * 0.42, h * 0.75)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.30, h * 0.68)
      ..lineTo(w * 0.05, h * 0.55)
      ..lineTo(w * 0.36, h * 0.45)
      ..close();
    canvas.drawPath(body, paint);
    canvas.drawPath(
        body,
        Paint()
          ..color = const Color(0xFF6a6aaa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }

  void _paintWraithX(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3C3489)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.48)
      ..lineTo(w * 0.85, h * 0.55)
      ..lineTo(w * 0.68, h * 0.50)
      ..lineTo(w * 0.65, h * 0.85)
      ..lineTo(w * 0.56, h * 0.75)
      ..lineTo(w * 0.5, h * 0.82)
      ..lineTo(w * 0.44, h * 0.75)
      ..lineTo(w * 0.35, h * 0.85)
      ..lineTo(w * 0.32, h * 0.50)
      ..lineTo(w * 0.15, h * 0.55)
      ..lineTo(0, h * 0.48)
      ..lineTo(w * 0.30, h * 0.30)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF7F77DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // Centre glow dot
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.07,
      Paint()..color = const Color(0xFFCECBF6),
    );
  }

  @override
  bool shouldRepaint(_JetSvgPainter old) => old.id != id;
}

// ---------------------------------------------------------------------------
// Shield Burst SVG (circle + star, purple)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Dashed border painter (for tomorrow teaser card)
// ---------------------------------------------------------------------------
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e3a1e)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashW = 6.0;
    const dashGap = 4.0;
    const radius = 10.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
        const Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashW).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashW + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}

// ---------------------------------------------------------------------------
// Placeholder widgets (shown until real assets are provided)
// ---------------------------------------------------------------------------
class _ChestPlaceholder extends StatelessWidget {
  final String id;
  const _ChestPlaceholder({required this.id});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (id) {
      case 'basic':
        color = const Color(0xFF7a5c30);
      case 'rare':
        color = const Color(0xFFa07820);
      case 'epic':
        color = const Color(0xFF6a1020);
      default:
        color = const Color(0xFF3B6D11);
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: const Center(
        child: Icon(Icons.inbox_rounded,
            color: Colors.white54, size: 24),
      ),
    );
  }
}

class _GemChestPlaceholder extends StatelessWidget {
  const _GemChestPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF412402),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cAmber, width: 0.5),
      ),
      child: const Center(
        child: Icon(Icons.inbox_rounded, color: _cAmber, size: 22),
      ),
    );
  }
}

class _GiftChestPlaceholder extends StatelessWidget {
  const _GiftChestPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF173404),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cGreen, width: 0.5),
      ),
      child: const Center(
        child:
            Icon(Icons.card_giftcard, color: _cGreenLight, size: 28),
      ),
    );
  }
}

class _PuPlaceholder extends StatelessWidget {
  final String id;
  const _PuPlaceholder({required this.id});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (id) {
      case 'rapidfire':
        color = const Color(0xFF008080);
      case 'speed':
        color = const Color(0xFF1a7a1a);
      case 'bomb':
        color = const Color(0xFF7a5000);
      case 'hp':
        color = const Color(0xFF7a0a1a);
      default:
        color = const Color(0xFF3B6D11);
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
