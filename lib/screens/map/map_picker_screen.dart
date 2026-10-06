import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────
// OpenStreetMap + Nominatim
// 100% FREE — no API key needed
// Map tiles: OpenStreetMap (free forever)
// Geocoding: Nominatim (free, no key required)
// ─────────────────────────────────────────

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapCtrl = MapController();

  // Default: Accra, Ghana
  LatLng _center = const LatLng(5.6037, -0.1870);

  String _address  = 'Move the map to select location';
  bool   _loading  = false;
  bool   _locating = false;
  bool   _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _center = widget.initialLocation!;
      _reverseGeocode(_center);
    } else {
      _getCurrentLocation();
    }
  }

  // ── GPS ──
  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      _mapCtrl.move(loc, 16);
      setState(() => _center = loc);
      await _reverseGeocode(loc);
    } catch (_) {}
    if (mounted) setState(() => _locating = false);
  }

  // ── Reverse geocode using Nominatim (FREE) ──
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() { _loading = true; _address = 'Finding address...'; });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&addressdetails=1'
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'TEHCS-App/1.0 (admin@tehcs.com)',
        'Accept-Language': 'en',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final parts = [
          addr['house_number'],
          addr['road'] ?? addr['pedestrian'] ?? addr['path'],
          addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'],
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'],
          addr['state'],
          addr['country'],
        ].where((s) => s != null && s.toString().isNotEmpty).toList();
        setState(() => _address = parts.take(4).join(', '));
      } else {
        setState(() => _address =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      setState(() => _address =
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onPositionChanged(MapPosition pos, bool hasGesture) {
    if (hasGesture && pos.center != null) {
      setState(() {
        _center    = pos.center!;
        _isDragging = true;
        _address   = 'Release to confirm location...';
      });
    }
  }

  void _onPointerUp() {
    if (_isDragging) {
      setState(() => _isDragging = false);
      _reverseGeocode(_center);
    }
  }

  void _confirm() {
    if (_loading) return;
    Navigator.of(context).pop({
      'address': _address,
      'lat':     _center.latitude,
      'lng':     _center.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [

        // ── OPENSTREETMAP ──
        Listener(
          onPointerUp: (_) => _onPointerUp(),
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom:   15,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tehcs.app',
              ),
            ],
          ),
        ),

        // ── CENTRE PIN ──
        IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _isDragging ? AppTheme.gold : AppTheme.navy,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: (_isDragging ? AppTheme.gold : AppTheme.navy).withOpacity(.4),
                      blurRadius: _isDragging ? 20 : 8,
                      offset: const Offset(0, 4),
                    )],
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                ),
                // Pin stem
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: _isDragging ? 22 : 14,
                  decoration: BoxDecoration(
                    color: _isDragging ? AppTheme.gold : AppTheme.navy,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Shadow
                Container(
                  width: _isDragging ? 14 : 8,
                  height: _isDragging ? 5 : 3,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── TOP BAR ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.navy),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.1), blurRadius: 8)],
                  ),
                  child: Text('Drag map to select location',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                ),
              ),
            ]),
          ),
        ),

        // ── MY LOCATION BUTTON ──
        Positioned(
          right: 14, bottom: 200,
          child: GestureDetector(
            onTap: _getCurrentLocation,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 8)],
              ),
              child: _locating
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy))
                : const Icon(Icons.my_location_rounded, color: AppTheme.navy, size: 22),
            ),
          ),
        ),

        // ── ZOOM CONTROLS ──
        Positioned(
          right: 14, bottom: 260,
          child: Column(children: [
            _ZoomBtn(icon: Icons.add, onTap: () => _mapCtrl.move(_center, _mapCtrl.camera.zoom + 1)),
            const SizedBox(height: 4),
            _ZoomBtn(icon: Icons.remove, onTap: () => _mapCtrl.move(_center, _mapCtrl.camera.zoom - 1)),
          ]),
        ),

        // ── BOTTOM ADDRESS CARD ──
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _isDragging ? AppTheme.gold.withOpacity(.1) : AppTheme.navy.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_outlined,
                    color: _isDragging ? AppTheme.gold : AppTheme.navy, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SELECTED LOCATION', style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMute, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _loading
                      ? Row(key: const ValueKey('loading'), children: [
                          const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy)),
                          const SizedBox(width: 8),
                          Text('Finding address...', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute)),
                        ])
                      : Text(_address,
                          key: ValueKey(_address),
                          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark,
                            fontWeight: FontWeight.w500, height: 1.4)),
                  ),
                  const SizedBox(height: 3),
                  Text('${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                ])),
              ]),
              const SizedBox(height: 14),

              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _isDragging) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const StadiumBorder(), elevation: 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Confirm This Location',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ]),
                ),
              ),

              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.info_outline, size: 11, color: AppTheme.textMute),
                const SizedBox(width: 4),
                Text('Powered by OpenStreetMap · Free forever',
                  style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 6)]),
      child: Icon(icon, color: AppTheme.navy, size: 20),
    ),
  );
}
