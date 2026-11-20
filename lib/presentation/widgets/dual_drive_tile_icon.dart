import 'package:flutter/material.dart';

class DualDriveTileIcon extends StatelessWidget {
  const DualDriveTileIcon({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_rounded,
            color: Color(0xFF00E5FF),
            size: 50,
          ),
          Container(
            width: 2,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(
            Icons.directions_car_rounded,
            color: Color(0xFFB388FF),
            size: 50,
          ),
        ],
      ),
    );
  }
}
