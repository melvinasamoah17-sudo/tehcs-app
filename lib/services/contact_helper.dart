import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'region_service.dart';

/// TEHCS office contacts (Ghana + UK) and a picker to call either office.
class ContactHelper {
  static const ghanaOffice = '+233505108071';
  static const ukOffice    = '+447448468070';
  static const whatsApp    = '233240699329';

  /// Ghana head office (Twitch Empire Limited).
  static const ghanaAddress =
      '9th Floor Emporium, Movenpick Ambassador Hotel,\nIndependence Avenue, Accra, Ghana';
  static const ghanaGps = 'GA-107-8134';

  /// Open the Ghana office in Google Maps.
  static Future<void> directionsToGhanaOffice() async {
    final q = Uri.encodeComponent('Movenpick Ambassador Hotel, Independence Avenue, Accra, Ghana');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const _ghana = {'flag': '🇬🇭', 'name': 'Ghana Office', 'number': ghanaOffice, 'display': '+233 50 510 8071',
      'address': '$ghanaAddress\nGPS: $ghanaGps'};
  static const _uk    = {'flag': '🇬🇧', 'name': 'UK Office',    'number': ukOffice,    'display': '+44 7448 468070'};

  /// Both offices, the user's own country first.
  static List<Map<String, String>> get offices =>
      RegionService.current.isUK ? [_uk, _ghana] : [_ghana, _uk];

  static Future<void> call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Bottom sheet letting the user choose which office to ring.
  static Future<void> callOffice(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Our offices',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.navy)),
              const SizedBox(height: 10),
              for (final o in offices)
                ListTile(
                  leading: Text(o['flag']!, style: const TextStyle(fontSize: 26)),
                  title: Text(o['name']!,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppTheme.navyDark)),
                  subtitle: Text(
                      o['address'] == null ? o['display']! : '${o['display']}\n${o['address']}',
                      style: GoogleFonts.inter(color: AppTheme.textMute, height: 1.4)),
                  isThreeLine: o['address'] != null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (o['address'] != null)
                      IconButton(
                        tooltip: 'Directions',
                        icon: const Icon(Icons.directions_outlined, color: AppTheme.navy),
                        onPressed: () {
                          Navigator.pop(ctx);
                          directionsToGhanaOffice();
                        },
                      ),
                    const Icon(Icons.phone, color: AppTheme.navy),
                  ]),
                  onTap: () {
                    Navigator.pop(ctx);
                    call(o['number']!);
                  },
                ),
            ]),
          ),
        ),
      );
}
