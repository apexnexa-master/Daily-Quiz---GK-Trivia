import 'package:flutter/material.dart';

class AchievementTier {
  final int threshold;
  final int coinReward;
  final String label;

  const AchievementTier({
    required this.threshold,
    required this.coinReward,
    required this.label,
  });
}

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<AchievementTier> tiers;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.tiers,
  });

  int get maxTier => tiers.length;
  int get maxThreshold => tiers.last.threshold;
}

final List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'perfectionist',
    name: 'The Perfectionist',
    description: 'Clear maps with 3-star rating',
    icon: Icons.star,
    color: Colors.amber,
    tiers: [
      AchievementTier(threshold: 25, coinReward: 100, label: 'Bronze'),
      AchievementTier(threshold: 50, coinReward: 200, label: 'Silver'),
      AchievementTier(threshold: 100, coinReward: 500, label: 'Gold'),
      AchievementTier(threshold: 150, coinReward: 1000, label: 'Platinum'),
      AchievementTier(threshold: 200, coinReward: 2500, label: 'Diamond'),
    ],
  ),
  AchievementDef(
    id: 'tactician',
    name: 'Tactician',
    description: 'Complete maps without using hint',
    icon: Icons.psychology,
    color: Colors.teal,
    tiers: [
      AchievementTier(threshold: 15, coinReward: 75, label: 'Bronze'),
      AchievementTier(threshold: 30, coinReward: 150, label: 'Silver'),
      AchievementTier(threshold: 60, coinReward: 300, label: 'Gold'),
      AchievementTier(threshold: 100, coinReward: 750, label: 'Platinum'),
      AchievementTier(threshold: 150, coinReward: 1500, label: 'Diamond'),
    ],
  ),
  AchievementDef(
    id: 'daily_voyager',
    name: 'Daily Voyager',
    description: 'Maintain daily challenge streak',
    icon: Icons.local_fire_department,
    color: Colors.deepOrange,
    tiers: [
      AchievementTier(threshold: 7, coinReward: 100, label: 'Bronze'),
      AchievementTier(threshold: 30, coinReward: 300, label: 'Silver'),
      AchievementTier(threshold: 60, coinReward: 600, label: 'Gold'),
      AchievementTier(threshold: 100, coinReward: 1200, label: 'Platinum'),
      AchievementTier(threshold: 365, coinReward: 5000, label: 'Diamond'),
    ],
  ),
  AchievementDef(
    id: 'grid_explorer',
    name: 'Grid Explorer',
    description: 'Complete total levels',
    icon: Icons.map,
    color: Colors.indigo,
    tiers: [
      AchievementTier(threshold: 10, coinReward: 50, label: 'Bronze'),
      AchievementTier(threshold: 50, coinReward: 150, label: 'Silver'),
      AchievementTier(threshold: 250, coinReward: 500, label: 'Gold'),
      AchievementTier(threshold: 500, coinReward: 1500, label: 'Platinum'),
      AchievementTier(threshold: 1000, coinReward: 5000, label: 'Diamond'),
    ],
  ),
  AchievementDef(
    id: 'coin_collector',
    name: 'Coin Collector',
    description: 'Accumulate total coins earned',
    icon: Icons.monetization_on,
    color: Colors.amber,
    tiers: [
      AchievementTier(threshold: 1000, coinReward: 100, label: 'Bronze'),
      AchievementTier(threshold: 5000, coinReward: 300, label: 'Silver'),
      AchievementTier(threshold: 25000, coinReward: 750, label: 'Gold'),
      AchievementTier(threshold: 100000, coinReward: 2000, label: 'Platinum'),
      AchievementTier(threshold: 500000, coinReward: 5000, label: 'Diamond'),
    ],
  ),
];
