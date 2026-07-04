import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  final String service;
  final String icon;
  const BookingScreen({super.key, required this.service, required this.icon});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _dateCtrl  = TextEditingController();
  final _timeCtrl  = TextEditingController();
  final _addrCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading  = false;
  bool _success  = false;
  String? _error;

  // EmailJS keys
  static const _ejKey = 'L79E9hHNieJbHYZL0';
  static const _ejSvc = 'service_g0m8tdi';
  static const _ejBiz = 'template_kswcorr';
  static const _ejClt = 'template_zljgoy6';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.navy, onPrimary: AppTheme.white, secondary: AppTheme.gold),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.navy, onPrimary: AppTheme.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _timeCtrl.text = picked.format(context);
    }
  }

  Future<void> _sendEmail(String template, Map<String, String> params) async {
    await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json', 'origin': 'https://tehcs.com'},
      body: jsonEncode({
        'service_id':  _ejSvc,
        'template_id': template,
        'user_id':     _ejKey,
        'template_params': params,
      }),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user     = FirebaseAuth.instance.currentUser!;
    final name     = user.displayName ?? user.email!.split('@').first;
    final email    = user.email!;
    final date     = _dateCtrl.text;
    final time     = _timeCtrl.text.isEmpty ? 'Flexible' : _timeCtrl.text;
    final address  = _addrCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();
    final notes    = _notesCtrl.text.trim();
    final service  = widget.service;
    final icon     = widget.icon;
    final ts       = DateTime.now().toString();

    try {
      debugPrint('Attempting to save booking to Firestore...');
      // 1. Save to Firestore
      await FirebaseFirestore.instance.collection('bookings').add({
        'uid':         user.uid,
        'clientName':  name,
        'clientEmail': email,
        'phone':       phone,
        'service':     service,
        'icon':        icon,
        'date':        date,
        'time':        time,
        'address':     address,
        'notes':       notes,
        'status':      'pending',
        'createdAt':   FieldValue.serverTimestamp(),
      });
      debugPrint('Booking saved to Firestore successfully');

      // 2. Notifications (EmailJS)
      try {
        debugPrint('Attempting to send notification emails...');
        // Notify TEHCS
        await _sendEmail(_ejBiz, {
          'from_name':  name,
          'from_email': email,
          'phone':      phone,
          'country':    'Via TEHCS App',
          'service':    service,
          'message':    '🔖 NEW APP BOOKING\nService: $service\nDate: $date\nTime: $time\nAddress: $address\nPhone: $phone\nNotes: ${notes.isEmpty ? "None" : notes}',
          'timestamp':  ts,
          'reply_to':   email,
        });

        // Confirmation to client
        await _sendEmail(_ejClt, {
          'from_name':  name,
          'from_email': email,
          'phone':      phone,
          'service':    service,
          'message':    'Your booking for "$service" on $date${time != "Flexible" ? " at $time" : ""} has been received. We will contact you on $phone within 24 hours.\n\nAddress: $address',
          'timestamp':  ts,
          'reply_to':   'twitchempireinfo@gmail.com',
        });
        debugPrint('Notification emails sent successfully');
      } catch (e) {
        debugPrint('Email notification failed: $e');
        // We don't fail the whole process if email fails, as it's saved in Firestore
      }

      if (mounted) setState(() { _loading = false; _success = true; });
    } catch (e) {
      debugPrint('Booking error: $e');
      String msg = e.toString();
      if (msg.contains('permission-denied')) {
        msg = 'Permission denied. Please check your Firestore rules.';
      }
      if (mounted) setState(() { _loading = false; _error = 'Booking failed: $msg'; });
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose(); _timeCtrl.dispose(); _addrCtrl.dispose();
    _phoneCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.icon} Book Service',
          style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.white, letterSpacing: 0.8),
        ),
      ),
      body: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service header
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Text(widget.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.service,
                    style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 0.5),
                  ),
                  Text('Fill in the details below',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w300),
                  ),
                ],
              )),
            ]),
          ),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text('⚠️ $_error', style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFFB91C1C))),
            ),
          ],

          // Date
          _label('Preferred Date *'),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tap to select date',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                  suffixIcon: Icon(Icons.arrow_drop_down, size: 22),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please select a date' : null,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Time
          _label('Preferred Time (optional)'),
          GestureDetector(
            onTap: _pickTime,
            child: AbsorbPointer(
              child: TextFormField(
                controller: _timeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tap to select time (optional)',
                  prefixIcon: Icon(Icons.access_time_outlined, size: 20),
                  suffixIcon: Icon(Icons.arrow_drop_down, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Address
          _label('Address / Location *'),
          TextFormField(
            controller: _addrCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Your home or work address',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your address' : null,
          ),
          const SizedBox(height: 14),

          // Phone
          _label('Phone / WhatsApp *'),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+233 or +44...',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your phone number' : null,
          ),
          const SizedBox(height: 14),

          // Notes
          _label('Additional Notes (optional)'),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Any specific details about your needs...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.notes_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.gold.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppTheme.goldDark, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'TEHCS will contact you within 24 hours to confirm your booking.',
                style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w400, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 22),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const StadiumBorder(),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Confirm Booking',
                style: GoogleFonts.barlowCondensed(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: const Color(0xFFEAFAF1), shape: BoxShape.circle),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 24),
          Text('Booking Confirmed!',
            style: GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Your request for ${widget.service} has been received. TEHCS will contact you within 24 hours to confirm.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.7),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _successRow('📧', 'Confirmation email sent'),
                _successRow('📋', 'Saved to your bookings'),
                _successRow('📞', 'We\'ll call or WhatsApp you soon'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark, padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
              child: Text('Done', style: GoogleFonts.barlowCondensed(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _successRow(String emoji, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Text(text, style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w400)),
    ]),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(),
      style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMid, letterSpacing: 1.2),
    ),
  );
}