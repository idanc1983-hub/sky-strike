import 'package:flutter/material.dart';

enum JetStatus { equipped, owned, purchasable, locked }

class JetModel {
  final String id;
  final String name;
  final String tier;
  final int speed;
  final int attack;
  final int armor;
  final Color accentColor;
  final Color bgColor;
  final JetStatus status;
  final int price;
  final String? unlockCondition;
  final String? unlockBiome;
  final int unlockWorld;
  final String assetPath;

  const JetModel({
    required this.id,
    required this.name,
    required this.tier,
    required this.speed,
    required this.attack,
    required this.armor,
    required this.accentColor,
    required this.bgColor,
    required this.status,
    this.price = 0,
    this.unlockCondition,
    this.unlockBiome,
    this.unlockWorld = 1,
    required this.assetPath,
  });

  JetModel copyWith({JetStatus? status}) {
    return JetModel(
      id: id,
      name: name,
      tier: tier,
      speed: speed,
      attack: attack,
      armor: armor,
      accentColor: accentColor,
      bgColor: bgColor,
      status: status ?? this.status,
      price: price,
      unlockCondition: unlockCondition,
      unlockBiome: unlockBiome,
      unlockWorld: unlockWorld,
      assetPath: assetPath,
    );
  }
}
