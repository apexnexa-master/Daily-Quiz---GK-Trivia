// lib/core/theme/app_icons.dart
import 'package:flutter/material.dart';

class AppIcons {
  AppIcons._();

  // Navigation
  static const IconData home = Icons.home_rounded;
  static const IconData leaderboard = Icons.leaderboard_rounded;
  static const IconData profile = Icons.person_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData battle = Icons.sports_kabaddi_rounded;
  static const IconData challenge = Icons.sports_kabaddi_rounded;
  static const IconData fight = Icons.flash_on_rounded;

  // Alternate for battle if swords is not available in basic material:
  static const IconData battleAlternative = Icons.flash_on_rounded;
  static const IconData pvp = Icons.flash_on_rounded;

  // Gamification & Stats
  static const IconData xp = Icons.bolt_rounded;
  static const IconData streak = Icons.local_fire_department_rounded;
  static const IconData coin = Icons.monetization_on_rounded;
  static const IconData life = Icons.favorite_rounded;
  static const IconData lifeBorder = Icons.favorite_border_rounded;
  static const IconData level = Icons.workspace_premium_rounded;
  static const IconData achievement = Icons.emoji_events_rounded;
  static const IconData trophy = Icons.emoji_events_outlined;
  static const IconData crown = Icons.workspace_premium_sharp;

  // Quiz Gameplay
  static const IconData timer = Icons.timer_rounded;
  static const IconData question = Icons.help_outline_rounded;
  static const IconData correct = Icons.check_circle_rounded;
  static const IconData incorrect = Icons.cancel_rounded;
  static const IconData explanation = Icons.lightbulb_rounded;
  static const IconData bookmarkActive = Icons.bookmark_rounded;
  static const IconData bookmarkInactive = Icons.bookmark_border_rounded;
  
  // Powerups / Lifelines
  static const IconData halfHalf = Icons.star_half_rounded;
  static const IconData skip = Icons.skip_next_rounded;
  static const IconData hint = Icons.lightbulb_outline_rounded;

  // General Actions & Controls
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData retry = Icons.replay_rounded;
  static const IconData next = Icons.arrow_forward_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData notificationBell = Icons.notifications_active_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;

  // Category Icons Map
  static const Map<String, IconData> _categoryIcons = {
    'General Knowledge': Icons.menu_book_rounded,
    'Indian History': Icons.history_edu_rounded,
    'Geography': Icons.public_rounded,
    'Science': Icons.science_rounded,
    'Polity': Icons.gavel_rounded,
    'Economy': Icons.trending_up_rounded,
    'Current Affairs': Icons.feed_rounded,
    'Art & Culture': Icons.palette_rounded,
  };

  static IconData categoryIcon(String category) {
    return _categoryIcons[category] ?? Icons.quiz_rounded;
  }

  // Exam Mode Icons Map
  static const Map<String, IconData> _examModeIcons = {
    'GENERAL': Icons.school_rounded,
    'WBPSC': Icons.account_balance_rounded,
    'SSC': Icons.description_rounded,
    'UPSC': Icons.military_tech_rounded,
    'BANK': Icons.savings_rounded,
  };

  static IconData examModeIcon(String mode) {
    return _examModeIcons[mode.toUpperCase()] ?? Icons.import_contacts_rounded;
  }

  // Medals for ranks
  static IconData medalForRank(int rank) {
    if (rank == 1) return Icons.emoji_events_rounded; // Gold
    if (rank == 2) return Icons.military_tech_rounded; // Silver
    if (rank == 3) return Icons.workspace_premium_rounded; // Bronze
    return Icons.star_border_rounded;
  }
}
