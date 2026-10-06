import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ServiceChip extends StatelessWidget {
  final String name;
  final String icon;
  final String category;
  final VoidCallback onTap;
  final double width;

  const ServiceChip({
    super.key,
    required this.name,
    required this.icon,
    required this.category,
    required this.onTap,
    this.width = 100,
  });

  Color get _catColor => switch (category) {
    'Healthcare'   => AppTheme.goldDark,
    'Construction' => AppTheme.navy,
    _              => AppTheme.red,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: AppTheme.navy, letterSpacing: 0.2, height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
            child: Text(category,
              style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: _catColor, letterSpacing: 0.3),
            ),
          ),
        ]),
      ),
    );
  }
}