import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'admin_panel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;
  bool _isStaff = false;
  final String primaryAdminEmail = 'twitchempireinfo@gmail.com';

  @override
  void initState() {
    super.initState();
    _checkStaffStatus();
  }

  Future<void> _checkStaffStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (user.email == primaryAdminEmail) {
      if (mounted) setState(() => _isStaff = true);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user.email)
          .get();
      
      if (snap.docs.isNotEmpty && mounted) {
        setState(() => _isStaff = true);
      }
    } catch (e) {
      debugPrint('Staff check error: $e');
    }
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _name  => _user?.displayName ?? _user?.email?.split('@').first ?? 'User';
  String get _email => _user?.email ?? '';
  
  String get _initials {
    final name = _name.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_user == null) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    if (mounted) setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('profiles').child('${_user!.uid}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      await _user!.updatePhotoURL(url);
      await _user!.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated!'), backgroundColor: AppTheme.green),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _editProfile() async {
    final ctrl = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Profile', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Full Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && _user != null) {
      try {
        await _user!.updateDisplayName(newName);
        await _user!.reload();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Update name error: $e');
      }
    }
  }

  void _handleAdminPortal() async {
    if (_user?.email == primaryAdminEmail) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('ADMIN OPTIONS', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.bold)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'admin'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Admin Portal (Manage Staff & Bookings)', style: GoogleFonts.nunito()),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'staff'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Staff View (Bookings Only)', style: GoogleFonts.nunito()),
              ),
            ),
          ],
        ),
      );

      if (choice != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AdminPanel(mode: choice),
        ));
      }
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AdminPanel(mode: 'staff'),
      ));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, shape: const StadiumBorder()),
            child: Text('Sign Out', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.navyDark, AppTheme.navy],
                ),
              ),
              child: Column(children: [
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
                          image: _user?.photoURL != null 
                            ? DecorationImage(image: NetworkImage(_user!.photoURL!), fit: BoxFit.cover)
                            : null,
                        ),
                        child: _user?.photoURL == null 
                          ? Center(child: Text(_initials, style: GoogleFonts.barlowCondensed(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.navyDark)))
                          : null,
                      ),
                      if (_uploading)
                        const Positioned.fill(child: Center(child: CircularProgressIndicator(color: AppTheme.white))),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 16, color: AppTheme.navyDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(_name.toUpperCase(), style: GoogleFonts.barlowCondensed(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.white)),
                Text(_email, style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54)),
              ]),
            ),

            if (_isStaff)
              _section('Management', [
                _MenuItem(icon: Icons.admin_panel_settings, label: 'Admin Portal', onTap: _handleAdminPortal),
              ]),

            _section('Account', [
              _MenuItem(icon: Icons.person_outline, label: 'Edit Profile', onTap: _editProfile),
              _MenuItem(icon: Icons.calendar_today_outlined, label: 'My Bookings', onTap: () {}),
            ]),

            _section('Contact & Support', [
              _MenuItem(icon: Icons.email_outlined, label: 'Email Support', onTap: () => _launch('mailto:twitchempireinfo@gmail.com')),
              _MenuItem(icon: Icons.language_outlined, label: 'Visit Website', onTap: () => _launch('https://tehcs.com')),
              _MenuItem(icon: Icons.chat_outlined, label: 'WhatsApp', onTap: () => _launch('https://wa.me/233240699329')),
            ]),

            _section('App', [
              _MenuItem(icon: Icons.share_outlined, label: 'Share App', onTap: () => Share.share('Download TEHCS App: https://tehcs.com')),
              _MenuItem(icon: Icons.star_outline, label: 'Rate App', onTap: () => _launch('https://tehcs.com')),
            ]),

            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('SIGN OUT'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<_MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
            child: Column(
              children: items.map((item) => ListTile(
                leading: Icon(item.icon, color: AppTheme.navy, size: 20),
                title: Text(item.label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: item.onTap,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});
}
