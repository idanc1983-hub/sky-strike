import 'package:flutter/material.dart';

enum PowerUpCategory { instant, collectible }

enum PowerUpType {
  // INSTANT — auto-apply on pickup, never enter tray
  rapidFire,
  speedBoost,
  shield,
  magnet,
  ghostMode,
  // COLLECTIBLE — stored in tray, tap to activate
  bomb,
  splitShot,
  laser,
  freezeTime,
  droneWingman,
  // Legacy instant
  hp,
  // Currency drop — adds coins to wallet on pickup
  coins,
}

extension PowerUpTypeX on PowerUpType {
  PowerUpCategory get category {
    switch (this) {
      case PowerUpType.rapidFire:
      case PowerUpType.speedBoost:
      case PowerUpType.shield:
      case PowerUpType.magnet:
      case PowerUpType.ghostMode:
      case PowerUpType.hp:
      case PowerUpType.coins:
        return PowerUpCategory.instant;
      case PowerUpType.bomb:
      case PowerUpType.splitShot:
      case PowerUpType.laser:
      case PowerUpType.freezeTime:
      case PowerUpType.droneWingman:
        return PowerUpCategory.collectible;
    }
  }

  // Asset path for the falling orb on canvas (null = use placeholder)
  String? get dropAsset {
    switch (this) {
      case PowerUpType.bomb:        return 'assets/ui/pu_bomb_drop.png';
      case PowerUpType.laser:       return 'assets/ui/pu_laser_drop.png';
      case PowerUpType.magnet:      return 'assets/ui/pu_magnet_drop.png';
      case PowerUpType.ghostMode:   return 'assets/ui/pu_ghost_drop.png';
      case PowerUpType.freezeTime:  return 'assets/ui/pu_freeze_drop.png';
      case PowerUpType.rapidFire:   return 'assets/ui/pu_rapidfire.png';
      case PowerUpType.speedBoost:  return 'assets/ui/pu_speed.png';
      case PowerUpType.hp:          return 'assets/ui/pu_hp.png';
      case PowerUpType.shield:      return 'assets/ui/pu_shield.png';
      case PowerUpType.splitShot:   return 'assets/ui/pu_split_shot_drop.png';
      case PowerUpType.droneWingman: return 'assets/ui/pu_drone_drop.png';
      case PowerUpType.coins:       return 'assets/ui/pu_coins_drop.png';
    }
  }

  // Asset path for the tray slot icon (null = instant types, no slot)
  String? get slotAsset {
    switch (this) {
      case PowerUpType.bomb:         return 'assets/ui/pu_bomb_slot.png';
      case PowerUpType.splitShot:    return 'assets/ui/pu_split_shot_slot.png';
      case PowerUpType.laser:        return 'assets/ui/pu_laser_slot.png';
      case PowerUpType.freezeTime:   return 'assets/ui/pu_freeze_slot.png';
      case PowerUpType.droneWingman: return 'assets/ui/pu_drone_slot.png';
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

  // Fixed tray slot index for collectibles (-1 for instants)
  int get slotIndex {
    switch (this) {
      case PowerUpType.bomb:         return 0;
      case PowerUpType.splitShot:    return 1;
      case PowerUpType.laser:        return 2;
      case PowerUpType.freezeTime:   return 3;
      case PowerUpType.droneWingman: return 4;
      default:                       return -1;
    }
  }

  // Effect duration in frames at 60 fps (-1 = non-timed)
  int get durationFrames {
    switch (this) {
      case PowerUpType.rapidFire:    return 300;
      case PowerUpType.shield:       return -1;
      case PowerUpType.splitShot:    return 300;
      case PowerUpType.speedBoost:   return 300;
      case PowerUpType.droneWingman: return 300;
      case PowerUpType.bomb:         return 1;
      case PowerUpType.laser:        return 180;
      case PowerUpType.magnet:       return 480;
      case PowerUpType.ghostMode:    return 180;
      case PowerUpType.freezeTime:   return 240;
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
}

// Fixed order of collectible slots in the tray (unlock order, W1→W5)
const List<PowerUpType> kCollectibleSlots = [
  PowerUpType.bomb,
  PowerUpType.splitShot,
  PowerUpType.laser,
  PowerUpType.freezeTime,
  PowerUpType.droneWingman,
];

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
