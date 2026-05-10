/// Ace's facial expression variant for a dialogue line — maps to
/// `assets/ui/ace_<expression>.png`.
enum AceExpression { smirk, cheer, concerned, excited }

extension AceExpressionAsset on AceExpression {
  /// Asset path for this expression's portrait sprite (256×256).
  String get assetPath {
    switch (this) {
      case AceExpression.smirk:
        return 'assets/ui/ace_smirk.png';
      case AceExpression.cheer:
        return 'assets/ui/ace_cheer.png';
      case AceExpression.concerned:
        return 'assets/ui/ace_concerned.png';
      case AceExpression.excited:
        return 'assets/ui/ace_excited.png';
    }
  }
}

/// One line of Ace dialogue with the expression to render alongside it.
class AceLine {
  final String text;
  final AceExpression expression;
  const AceLine(this.text, this.expression);
}

/// Stable string keys for every Ace dialogue line in the FTUE and
/// post-FTUE moments. Keys are used both as the lookup ID in
/// [AceDialogueCatalog.line] and as the persistent record of which lines
/// have been shown (per `EconomyState.shownAceLines`).
class AceLineKeys {
  AceLineKeys._();

  // First mission — pre-mission popup
  static const ftuePreMission1 = 'ftue_pre_mission_1';
  static const ftuePreMission2 = 'ftue_pre_mission_2';

  // First mission — in-game waves
  static const ftueWave1Start = 'ftue_wave_1_start';
  static const ftueWave2Start = 'ftue_wave_2_start';
  static const ftueWave3Start = 'ftue_wave_3_start';
  static const ftueStage1Clear = 'ftue_stage_1_clear';
  static const ftueShopIntro = 'ftue_shop_intro';
  static const ftueShopSuggest = 'ftue_shop_suggest';
  static const ftueStage2Start = 'ftue_stage_2_start';

  // First death
  static const ftueFirstDeath = 'ftue_first_death';
  static const ftueReviveYes = 'ftue_revive_yes';
  static const ftueReviveNo = 'ftue_revive_no';

  // Power-up unlocks (per power-up id)
  static const aceUnlockBomb = 'ace_unlock_bomb';
  static const aceUnlockMagnet = 'ace_unlock_magnet';
  static const aceUnlockShield = 'ace_unlock_shield';
  static const aceUnlockSplitShot = 'ace_unlock_split_shot';
  static const aceUnlockLaser = 'ace_unlock_laser';
  static const aceUnlockGhostMode = 'ace_unlock_ghost_mode';
  static const aceUnlockFreezeTime = 'ace_unlock_freeze_time';
  static const aceUnlockDroneWingman = 'ace_unlock_drone_wingman';

  // Long-term milestones
  static const aceDay7Streak = 'ace_day7_streak';
  static const aceLevel10 = 'ace_level_10';
  static const aceLevel25 = 'ace_level_25';
  static const aceLevel50 = 'ace_level_50';
  static const aceFirstW1Boss = 'ace_first_w1_boss';
  static const aceFirstJet = 'ace_first_jet';

  // Stage 3 challenge reveal — final bubble after returning home
  static const aceChallengeRevealClose = 'ace_challenge_reveal_close';
}

/// Lookup table for every Ace dialogue line. Keys are stable IDs from
/// [AceLineKeys]; values are the text + expression to render.
class AceDialogueCatalog {
  AceDialogueCatalog._();

  /// All lines in display-time-of-game order. Use [line] for lookup.
  static const Map<String, AceLine> lines = <String, AceLine>{
    AceLineKeys.ftuePreMission1: AceLine(
      "Hey rookie! First flight? Stick with me — we got skies to clear.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftuePreMission2: AceLine(
      "Just hit LAUNCH when you're ready.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueWave1Start: AceLine(
      "Drag to fly. Just don't crash.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueWave2Start: AceLine(
      "Green packs heal you up. Grab 'em.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueWave3Start: AceLine(
      "Nice flying, kid.",
      AceExpression.cheer,
    ),
    AceLineKeys.ftueStage1Clear: AceLine(
      "Hell yes! That's how it's done!",
      AceExpression.cheer,
    ),
    AceLineKeys.ftueShopIntro: AceLine(
      "Coins go a long way at the shop. Take a peek before you launch again.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueShopSuggest: AceLine(
      "Speed Boost saves your skin. Try it for next mission.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueStage2Start: AceLine(
      "Round two, rookie.",
      AceExpression.smirk,
    ),
    AceLineKeys.ftueFirstDeath: AceLine(
      "Hey, even I crashed my first time. Want another shot?",
      AceExpression.concerned,
    ),
    AceLineKeys.ftueReviveYes: AceLine(
      "That's the spirit.",
      AceExpression.cheer,
    ),
    AceLineKeys.ftueReviveNo: AceLine(
      "No worries. Pick yourself up — try again.",
      AceExpression.concerned,
    ),
    AceLineKeys.aceUnlockBomb: AceLine(
      "BIG one! Tap to drop a bomb. Clears the screen.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockMagnet: AceLine(
      "Magnet pulls coins right to you. Beautiful.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockShield: AceLine(
      "Shield's a lifesaver. Pop it before things get hairy.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockSplitShot: AceLine(
      "Three shots for the price of one. My favorite.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockLaser: AceLine(
      "Whoa. THAT is a laser. Use it on the big ones.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockGhostMode: AceLine(
      "Phase through bullets. You're invincible for a sec.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockFreezeTime: AceLine(
      "Stop time. The whole damn screen. Glorious.",
      AceExpression.excited,
    ),
    AceLineKeys.aceUnlockDroneWingman: AceLine(
      "Got you a wingman. Now there's two of us.",
      AceExpression.excited,
    ),
    AceLineKeys.aceDay7Streak: AceLine(
      "Week one done. You're officially a pilot now.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceLevel10: AceLine(
      "Level 10. You're not a rookie anymore.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceLevel25: AceLine(
      "Quarter to a hundred. Damn, kid.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceLevel50: AceLine(
      "Halfway to legend. Keep flying.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceFirstW1Boss: AceLine(
      "First boss down! Welcome to the big leagues.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceFirstJet: AceLine(
      "Now THAT'S a beautiful machine.",
      AceExpression.cheer,
    ),
    AceLineKeys.aceChallengeRevealClose: AceLine(
      "Track your progress here. Good luck, ace.",
      AceExpression.smirk,
    ),
  };

  /// Returns the line for [key] or `null` if the key is unknown.
  static AceLine? line(String key) => lines[key];

  /// Maps a power-up id to its Ace unlock line key. Returns `null` for
  /// power-ups that don't have a dedicated unlock line (e.g. Rapid Fire,
  /// Speed Boost — those are W1 and don't trigger an Ace cutscene).
  static String? unlockLineKeyForPowerUp(String powerUpId) {
    switch (powerUpId) {
      case 'bomb':
        return AceLineKeys.aceUnlockBomb;
      case 'magnet':
        return AceLineKeys.aceUnlockMagnet;
      case 'shield':
        return AceLineKeys.aceUnlockShield;
      case 'split_shot':
        return AceLineKeys.aceUnlockSplitShot;
      case 'laser':
        return AceLineKeys.aceUnlockLaser;
      case 'ghost_mode':
        return AceLineKeys.aceUnlockGhostMode;
      case 'freeze_time':
        return AceLineKeys.aceUnlockFreezeTime;
      case 'drone_wingman':
        return AceLineKeys.aceUnlockDroneWingman;
      default:
        return null;
    }
  }
}
