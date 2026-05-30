/// Saved jet preset. POWERUP-v2.1 retired the fixed-slot tray, so a
/// loadout is now just a named jet selection.
class Loadout {
  String name;
  String jetId;

  Loadout({
    required this.name,
    required this.jetId,
  });

  /// Default loadout for a brand-new player.
  factory Loadout.defaultFor(int index) =>
      Loadout(name: 'Loadout ${index + 1}', jetId: 'jet_player');

  /// Deep copy.
  Loadout clone() => Loadout(name: name, jetId: jetId);

  Map<String, dynamic> toJson() => {
        'name': name,
        'jetId': jetId,
      };

  factory Loadout.fromJson(Map<String, dynamic> json) {
    return Loadout(
      name: (json['name'] as String?) ?? 'Loadout',
      jetId: (json['jetId'] as String?) ?? 'jet_player',
    );
  }
}
