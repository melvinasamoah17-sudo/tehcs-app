import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  final bool showProgress;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.showProgress = false,
  });

  Color get _statusColor => switch (booking.status) {
    'active'   => AppTheme.green,
    'complete' => AppTheme.navy,
    _          => AppTheme.goldDark,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.navy.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(children: [
                Text(booking.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(booking.service,
                  style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                  child: Text(booking.status.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w800, color: _statusColor, letterSpacing: 0.6),
                  ),
                ),
              ]),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _row(Icons.calendar_today_outlined, booking.date.isEmpty ? 'TBD' : booking.date),
                const SizedBox(height: 5),
                _row(Icons.access_time_outlined,    booking.time.isEmpty ? 'Flexible' : booking.time),
                if (booking.address.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _row(Icons.location_on_outlined, booking.address.length > 32 ? '${booking.address.substring(0,32)}...' : booking.address),
                ],
              ]),
            ),

            // Progress bar (active only)
            if (booking.status == 'active' && showProgress)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('In Progress', style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green, letterSpacing: 0.5)),
                    Text('60%', style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: 0.6, backgroundColor: AppTheme.light, valueColor: const AlwaysStoppedAnimation(AppTheme.green), minHeight: 4),
                  ),
                ]),
              ),

            // Tap indicator
            if (onTap != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Text('Tap for details',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: AppTheme.textMute),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300))),
  ]);
}