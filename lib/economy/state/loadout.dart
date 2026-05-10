import '../constants/economy_constants.dart';

/// Saved jet+power-up preset. The player can switch between loadouts
/// instantly from the pre-mission screen. There are up to
/// [EconomyConstants.maxLoadoutSlots] (5) loadouts; only the first
/// [EconomyState.unlockedLoadoutSlots] are user-editable.
class Loadout {
  String name;
  String jetId;

  /// Power-up ids occupying each tray cell (length =
  /// [EconomyConstants.trayPowerUpCount]). `null` means an empty cell.
  final List<String?> trayPowerUps;

  Loadout({
    required this.name,
    required this.jetId,
    List<String?>? trayPowerUps,
  }) : trayPowerUps = trayPowerUps ??
            List<String?>.filled(EconomyConstants.trayPowerUpCount, null);

  /// Default loadout for a brand-new player. Empty tray, basic jet.
  factory Loadout.defaultFor(int index) =>
      Loadout(name: 'Loadout ${index + 1}', jetId: 'jet_player');

  /// Number of tray cells currently holding a power-up.
  int get filledSlotCount =>
      trayPowerUps.where((slot) => slot != null).length;

  /// Returns the index of the first empty tray cell within the
  /// `[0, ownedSlotCount)` range, or `-1` if none.
  int firstEmptySlotIndex(int ownedSlotCount) {
    final upper =
        ownedSlotCount.clamp(0, EconomyConstants.trayPowerUpCount);
    for (var i = 0; i < upper; i++) {
      if (trayPowerUps[i] == null) return i;
    }
    return -1;
  }

  /// Whether [powerUpId] is already present in the tray (any slot within
  /// the owned range).
  bool trayContains(String powerUpId, int ownedSlotCount) {
    final upper =
        ownedSlotCount.clamp(0, EconomyConstants.trayPowerUpCount);
    for (var i = 0; i < upper; i++) {
      if (trayPowerUps[i] == powerUpId) return true;
    }
    return false;
  }

  /// Replaces the tray cell at [slotIndex] with [powerUpId]. Caller is
  /// responsible for bounds checking against owned slot count.
  void setSlot(int slotIndex, String? powerUpId) {
    trayPowerUps[slotIndex] = powerUpId;
  }

  /// Deep copy. Used by [EconomyState.loadouts] so external readers can
  /// never accidentally mutate persisted state via the inner tray list.
  Loadout clone() => Loadout(
        name: name,
        jetId: jetId,
        trayPowerUps: List<String?>.from(trayPowerUps),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'jetId': jetId,
        'trayPowerUps': trayPowerUps,
      };

  factory Loadout.fromJson(Map<String, dynamic> json) {
    final raw = (json['trayPowerUps'] as List?) ?? const <dynamic>[];
    final padded = List<String?>.filled(
      EconomyConstants.trayPowerUpCount,
      null,
    );
    for (var i = 0;
        i < raw.length && i < EconomyConstants.trayPowerUpCount;
        i++) {
      final value = raw[i];
      padded[i] = value is String ? value : null;
    }
    return Loadout(
      name: (json['name'] as String?) ?? 'Loadout',
      jetId: (json['jetId'] as String?) ?? 'jet_player',
      trayPowerUps: padded,
    );
  }
}
