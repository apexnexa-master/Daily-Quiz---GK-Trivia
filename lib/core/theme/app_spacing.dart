// lib/core/theme/app_spacing.dart
import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Spacing Scale Constants
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;

  // Reusable Vertical Gaps (SizedBox)
  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);
  static const SizedBox vXxxl = SizedBox(height: xxxl);
  static const SizedBox vHuge = SizedBox(height: huge);
  static const SizedBox vMassive = SizedBox(height: massive);

  // Reusable Horizontal Gaps (SizedBox)
  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);
  static const SizedBox hXxl = SizedBox(width: xxl);
  static const SizedBox hXxxl = SizedBox(width: xxxl);
  static const SizedBox hHuge = SizedBox(width: huge);
  static const SizedBox hMassive = SizedBox(width: massive);

  // Padding Presets
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
  static const EdgeInsets paddingCard = EdgeInsets.all(16.0);
  static const EdgeInsets paddingCardCondensed = EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0);
  static const EdgeInsets paddingSection = EdgeInsets.symmetric(vertical: 12.0);
  static const EdgeInsets paddingListSeparated = EdgeInsets.symmetric(vertical: 8.0);

  // Border Radius Constants
  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 16.0;
  static const double rXl = 20.0;
  static const double rXxl = 24.0;
  static const double rRound = 999.0;

  // Border Radius Presets
  static final BorderRadius radiusSm = BorderRadius.circular(rSm);
  static final BorderRadius radiusMd = BorderRadius.circular(rMd);
  static final BorderRadius radiusLg = BorderRadius.circular(rLg);
  static final BorderRadius radiusXl = BorderRadius.circular(rXl);
  static final BorderRadius radiusXxl = BorderRadius.circular(rXxl);
  static final BorderRadius radiusRound = BorderRadius.circular(rRound);
}
