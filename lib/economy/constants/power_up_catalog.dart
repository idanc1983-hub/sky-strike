/// Static metadata for the 10 power-ups defined by the GDD §2.6.
///
/// All values are **locked** by design — see GDD for rationale. Tuning
/// changes happen here and only here.
class PowerUpCatalog {
  PowerUpCatalog._();

  /// Biome at which each power-up unlocks. Keys are stable IDs used across
  /// state, persistence, and analytics. Values are `1..6` matching the
  /// v2 RC `economy__shop_powerups__v1.power_ups[*].unlock_biome`:
  /// 1=jungle, 2=desert, 3=sea, 4=ice, 5=volcano, 6=city.
  static const Map<String, int> unlockBiome = <String, int>{
    'rapid_fire': 1,
    'speed_boost': 1,
    'bomb': 1,
    'shield': 2,
    'split_shot': 2,
    'magnet': 3,
    'laser': 3,
    'freeze_time': 4,
    'ghost_mode': 5,
    'drone_wingman': 6,
  };

  /// `world → list of power-ups newly unlocked when that world is reached`.
  /// Computed lazily so it stays in sync with [unlockBiome].
  static final Map<int, List<String>> unlocksByWorld = _byWorld();

  /// All power-up ids in canonical (unlock-order) listing order.
  static final List<String> allIds = unlockBiome.keys.toList();

  /// Stackable / collectible-only ids — the subset that appears in the
  /// shop and in pre-mission quick-add rows. Instant power-ups are
  /// activated via gameplay paths only and are not shop-purchasable.
  /// Derived from [isCollectible] so the catalog stays the single
  /// source of truth.
  static final List<String> stackableIds =
      allIds.where((id) => isCollectible[id] == true).toList();

  /// Display name for the given id (used by popups + shop).
  static const Map<String, String> displayName = <String, String>{
    'rapid_fire': 'Rapid Fire',
    'speed_boost': 'Speed Boost',
    'bomb': 'Bomb',
    'magnet': 'Magnet',
    'shield': 'Shield',
    'split_shot': 'Split Shot',
    'laser': 'Laser',
    'ghost_mode': 'Ghost Mode',
    'freeze_time': 'Freeze Time',
    'drone_wingman': 'Drone Wingman',
  };

  /// One-line description shown on the unlock popup. Kept brief by design.
  static const Map<String, String> shortDescription = <String, String>{
    'rapid_fire': 'Doubles your fire rate',
    'speed_boost': 'Increases jet movement speed',
    'bomb': 'Clears the screen of enemies',
    'magnet': 'Pulls coins toward your jet',
    'shield': 'Absorbs the next hit',
    'split_shot': 'Fires three bullets in a spread',
    'laser': 'Continuous beam, pierces enemies',
    'ghost_mode': 'Brief invulnerability',
    'freeze_time': 'Slows all enemies for a few seconds',
    'drone_wingman': 'Auto-firing companion drone',
  };

  /// Indicates whether a power-up exists in the world as a *collectible*
  /// pickup (Bomb, Split Shot, Laser, Freeze Time, Drone Wingman) versus
  /// an *instant* effect auto-applied on pickup.
  static const Map<String, bool> isCollectible = <String, bool>{
    'rapid_fire': false,
    'speed_boost': false,
    'bomb': true,
    'magnet': false,
    'shield': false,
    'split_shot': true,
    'laser': true,
    'ghost_mode': false,
    'freeze_time': true,
    'drone_wingman': true,
  };

  /// Coin price to buy one copy in the shop. See [packDiscounts] for bulk
  /// pricing.
  static const Map<String, int> singlePrice = <String, int>{
    'rapid_fire': 50,
    'speed_boost': 50,
    'bomb': 80,
    'magnet': 70,
    'shield': 100,
    'split_shot': 100,
    'laser': 150,
    'ghost_mode': 180,
    'freeze_time': 200,
    'drone_wingman': 250,
  };

  /// Discount fractions by pack size — GDD §2.6 "Pack Size Discounts".
  /// Keys are pack sizes; values are the discount fraction (e.g. 0.10 for
  /// 10% off). Pack size 1 is undiscounted.
  static const Map<int, double> packDiscounts = <int, double>{
    1: 0.0,
    3: 0.10,
    5: 0.20,
    10: 0.30,
  };

  /// Returns the slot-icon asset path for [id]. Falls back to a
  /// known-existing sprite when no slot variant is on disk.
  static String slotIcon(String id) {
    switch (id) {
      case 'bomb':
        return 'assets/ui/pu_bomb_slot.png';
      case 'magnet':
        return 'assets/ui/pu_magnet_slot.png';
      case 'laser':
        return 'assets/ui/pu_laser_slot.png';
      case 'ghost_mode':
        return 'assets/ui/pu_ghost_slot.png';
      case 'freeze_time':
        return 'assets/ui/pu_freeze_slot.png';
      case 'rapid_fire':
        return 'assets/ui/pu_rapidfire.png';
      case 'speed_boost':
        return 'assets/ui/pu_speed.png';
      case 'shield':
        return 'assets/ui/pu_shield.png';
      case 'split_shot':
        return 'assets/ui/pu_split_shot_slot.png';
      case 'drone_wingman':
        return 'assets/ui/pu_drone_slot.png';
      default:
        return 'assets/ui/pu_bomb_slot.png';
    }
  }

  /// Returns the in-world drop-sprite asset path for [id].
  static String dropSprite(String id) {
    switch (id) {
      case 'bomb':
        return 'assets/ui/pu_bomb_drop.png';
      case 'magnet':
        return 'assets/ui/pu_magnet_drop.png';
      case 'laser':
        return 'assets/ui/pu_laser_drop.png';
      case 'ghost_mode':
        return 'assets/ui/pu_ghost_drop.png';
      case 'freeze_time':
        return 'assets/ui/pu_freeze_drop.png';
      case 'drone_wingman':
        return 'assets/ui/pu_drone_drop.png';
      default:
        return slotIcon(id);
    }
  }

  static Map<int, List<String>> _byWorld() {
    final out = <int, List<String>>{for (var w = 1; w <= 6; w++) w: []};
    for (final entry in unlockBiome.entries) {
      out[entry.value]!.add(entry.key);
    }
    return out;
  }
}
