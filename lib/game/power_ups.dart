import 'package:flutter/material.dart';

/// POWERUP-v2.1: every shop power-up is `stack` (held in inventory,
/// tapped to activate). [PowerUpType.hp] and [PowerUpType.coins] are not
/// power-ups in the catalog sense — they're auto-applied pickups handled
/// separately by the game loop and never enter the tray.
enum PowerUpType {
  // Stackable shop power-ups (10) — held in inventory, tap to activate.
  rapidFire,
  speedBoost,
  bomb,
  splitShot,
  shield,
  magnet,
  laser,
  freezeTime,
  ghostMode,
  droneWingman,
  // Auto-apply pickups — not in tray, not in shop.
  hp,
  coins,
}

extension PowerUpTypeX on PowerUpType {
  /// True for the 10 shop power-ups (stackable, tray-held, tap-activated).
  /// False for HP / coins, which auto-apply on pickup.
  bool get isStackable {
    switch (this) {
      case PowerUpType.hp:
      case PowerUpType.coins:
        return false;
      default:
        return true;
    }
  }

  /// Asset path for the falling orb on canvas.
  String get dropAsset {
    switch (this) {
      case PowerUpType.bomb:         return 'assets/ui/pu_bomb_drop.png';
      case PowerUpType.laser:        return 'assets/ui/pu_laser_drop.png';
      case PowerUpType.magnet:       return 'assets/ui/pu_magnet_drop.png';
      case PowerUpType.ghostMode:    return 'assets/ui/pu_ghost_mode_drop.png';
      case PowerUpType.freezeTime:   return 'assets/ui/pu_freeze_time_drop.png';
      case PowerUpType.rapidFire:    return 'assets/ui/pu_rapid_fire_drop.png';
      case PowerUpType.speedBoost:   return 'assets/ui/pu_speed_boost_drop.png';
      case PowerUpType.hp:           return 'assets/ui/pu_hp_drop.png';
      case PowerUpType.shield:       return 'assets/ui/pu_shield_drop.png';
      case PowerUpType.splitShot:    return 'assets/ui/pu_split_shot_drop.png';
      case PowerUpType.droneWingman: return 'assets/ui/pu_drone_wingman_drop.png';
      case PowerUpType.coins:        return 'assets/ui/pu_coins_drop.png';
    }
  }

  /// Tray slot icon. All stackable types render in the dynamic tray, so
  /// each needs a slot sprite. HP / coins don't enter the tray.
  String? get slotAsset {
    if (!isStackable) return null;
    switch (this) {
      case PowerUpType.bomb:         return 'assets/ui/pu_bomb_slot.png';
      case PowerUpType.splitShot:    return 'assets/ui/pu_split_shot_slot.png';
      case PowerUpType.laser:        return 'assets/ui/pu_laser_slot.png';
      case PowerUpType.freezeTime:   return 'assets/ui/pu_freeze_time_slot.png';
      case PowerUpType.droneWingman: return 'assets/ui/pu_drone_wingman_slot.png';
      case PowerUpType.rapidFire:    return 'assets/ui/pu_rapid_fire_slot.png';
      case PowerUpType.speedBoost:   return 'assets/ui/pu_speed_boost_slot.png';
      case PowerUpType.shield:       return 'assets/ui/pu_shield_slot.png';
      case PowerUpType.magnet:       return 'assets/ui/pu_magnet_slot.png';
      case PowerUpType.ghostMode:    return 'assets/ui/pu_ghost_mode_slot.png';
      default:                       return null;
    }
  }

  Color get accentColor {
    switch (this) {
      case PowerUpType.bomb:        return const Color(0xFFEF9F27);
      case PowerUpType.laser:       return const Color(0xFFE24B4A);
      case PowerUpType.magnet:      return const Color(0xFF7F77DD);
      case PowerUpType.ghostMode:   return const Color(0xFF5DCAA5);
      case PowerUpType.freezeTime:  return const Color(0xFF85B7EB);
      case PowerUpType.rapidFire:   return const Color(0xFF00CCCC);
      case PowerUpType.shield:      return const Color(0xFF7F77DD);
      case PowerUpType.splitShot:   return const Color(0xFFEF9F27);
      case PowerUpType.speedBoost:  return const Color(0xFF97C459);
      case PowerUpType.droneWingman: return const Color(0xFF5DCAA5);
      case PowerUpType.hp:          return const Color(0xFF97C459);
      case PowerUpType.coins:       return const Color(0xFFFFC83D);
    }
  }

  /// Active-effect duration in frames at 60fps. POWERUP-v2.1 Section 2:
  /// 7s for all timed effects, Ghost Mode 10s, Bomb instant. Shield is
  /// timed now (7s of damage absorption) per v2.1 — no longer untimed.
  /// HP / coins are instant-apply on pickup (1 frame marker).
  int get durationFrames {
    switch (this) {
      case PowerUpType.rapidFire:    return 420; // 7s
      case PowerUpType.speedBoost:   return 420; // 7s
      case PowerUpType.shield:       return 420; // 7s
      case PowerUpType.splitShot:    return 420; // 7s
      case PowerUpType.magnet:       return 420; // 7s
      case PowerUpType.laser:        return 420; // 7s
      case PowerUpType.freezeTime:   return 420; // 7s
      case PowerUpType.ghostMode:    return 600; // 10s
      case PowerUpType.droneWingman: return 420; // 7s
      case PowerUpType.bomb:         return 1;   // instant on tap
      case PowerUpType.hp:           return 1;
      case PowerUpType.coins:        return 1;
    }
  }

  String get displayName {
    switch (this) {
      case PowerUpType.rapidFire:    return 'Rapid\nFire';
      case PowerUpType.shield:       return 'Shield';
      case PowerUpType.splitShot:    return 'Split\nShot';
      case PowerUpType.speedBoost:   return 'Speed';
      case PowerUpType.droneWingman: return 'Drone';
      case PowerUpType.bomb:         return 'Bomb';
      case PowerUpType.laser:        return 'Laser';
      case PowerUpType.magnet:       return 'Magnet';
      case PowerUpType.ghostMode:    return 'Ghost';
      case PowerUpType.freezeTime:   return 'Freeze';
      case PowerUpType.hp:           return 'HP';
      case PowerUpType.coins:        return 'Coins';
    }
  }

  /// Stable id used by the catalog / economy layer. Null for HP and
  /// coins (not shop SKUs; not in the unlock table).
  String? get catalogId {
    switch (this) {
      case PowerUpType.rapidFire:    return 'rapid_fire';
      case PowerUpType.speedBoost:   return 'speed_boost';
      case PowerUpType.shield:       return 'shield';
      case PowerUpType.magnet:       return 'magnet';
      case PowerUpType.ghostMode:    return 'ghost_mode';
      case PowerUpType.bomb:         return 'bomb';
      case PowerUpType.splitShot:    return 'split_shot';
      case PowerUpType.laser:        return 'laser';
      case PowerUpType.freezeTime:   return 'freeze_time';
      case PowerUpType.droneWingman: return 'drone_wingman';
      case PowerUpType.hp:           return null;
      case PowerUpType.coins:        return null;
    }
  }
}

/// Catalog-id → PowerUpType lookup. Used by the dynamic tray to map
/// inventory keys back to render data.
final Map<String, PowerUpType> kPowerUpByCatalogId = {
  for (final t in PowerUpType.values)
    if (t.catalogId != null) t.catalogId!: t,
};

// ---------------------------------------------------------------------------
// Drop rates (independent roll per enemy kill)
// ---------------------------------------------------------------------------

const Map<PowerUpType, double> kNormalDropRates = {
  PowerUpType.rapidFire:    0.04,
  PowerUpType.speedBoost:   0.04,
  PowerUpType.shield:       0.02,
  PowerUpType.splitShot:    0.03,
  PowerUpType.droneWingman: 0.02,
  PowerUpType.hp:           0.05,
  PowerUpType.bomb:         0.02,
  PowerUpType.laser:        0.02,
  PowerUpType.magnet:       0.02,
  PowerUpType.ghostMode:    0.02,
  PowerUpType.freezeTime:   0.02,
  PowerUpType.coins:        0.08,
};

const Map<PowerUpType, double> kW1EarlyDropRates = {
  PowerUpType.rapidFire:    0.06,
  PowerUpType.speedBoost:   0.08,
  PowerUpType.shield:       0.02,
  PowerUpType.splitShot:    0.02,
  PowerUpType.droneWingman: 0.01,
  PowerUpType.hp:           0.15,
  PowerUpType.bomb:         0.01,
  PowerUpType.laser:        0.01,
  PowerUpType.magnet:       0.01,
  PowerUpType.ghostMode:    0.01,
  PowerUpType.freezeTime:   0.01,
  PowerUpType.coins:        0.10,
};

const Map<PowerUpType, double> kBoostDropRates = {
  PowerUpType.rapidFire:    0.10,
  PowerUpType.speedBoost:   0.10,
  PowerUpType.shield:       0.02,
  PowerUpType.splitShot:    0.05,
  PowerUpType.droneWingman: 0.04,
  PowerUpType.hp:           0.14,
  PowerUpType.bomb:         0.04,
  PowerUpType.laser:        0.03,
  PowerUpType.magnet:       0.03,
  PowerUpType.ghostMode:    0.03,
  PowerUpType.freezeTime:   0.03,
  PowerUpType.coins:        0.12,
};

Map<PowerUpType, double> normalDropRates(int world, int wave) {
  if (world == 1 && wave <= 5) return kW1EarlyDropRates;
  return kNormalDropRates;
}
