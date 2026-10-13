import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Helpers for phone sign-in and the admin's 2-step (SMS) verification.
class PhoneAuthHelper {
  /// Countries offered for phone sign-in: dial code -> label.
  static const Map<String, String> countries = {
    '233': '🇬🇭 +233',
    '44': '🇬🇧 +44',
  };

  /// "024 123 4567" (Ghana) or "07123 456789" (UK) -> E.164, using the
  /// chosen [dial] code. A number typed with +, 00 or the dial code is kept.
  static String normalize(String input, {String dial = '233'}) {
    var s = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.startsWith('+')) return s;
    if (s.startsWith('00')) return '+${s.substring(2)}';
    if (s.startsWith(dial)) return '+$s';
    if (s.startsWith('0')) return '+$dial${s.substring(1)}';
    return '+$dial$s';
  }

  /// Small country-code dropdown used beside phone fields.
  static Widget dialPicker(String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(left: 8, right: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            onChanged: (v) => onChanged(v ?? value),
            style: GoogleFonts.inter(color: AppTheme.navy, fontSize: 15),
            items: [
              for (final e in countries.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ),
      );

  static bool looksValid(String e164) =>
      RegExp(r'^\+\d{8,15}$').hasMatch(e164);

  static String friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That phone number is not valid.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a while and try again.';
        case 'quota-exceeded':
          return 'SMS limit reached. Try again later.';
        case 'invalid-verification-code':
          return 'Wrong code. Please check and try again.';
        case 'session-expired':
        case 'code-expired':
          return 'That code has expired. Request a new one.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'requires-recent-login':
          return 'Please sign out and sign in again, then retry.';
        case 'unverified-email':
          return 'Verify your email address first, then retry.';
        case 'second-factor-already-in-use':
          return 'This phone is already set up.';
        case 'operation-not-allowed':
          return 'SMS is not enabled for this region in Firebase '
              '(Authentication > Settings > SMS region policy).';
      }
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Asks the person for the 6-digit SMS code. Returns null if cancelled.
  static Future<String?> askCode(BuildContext context, String sentTo) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Enter the code',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppTheme.navy)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('We sent a 6-digit code by SMS to $sentTo.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textMid)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
                color: AppTheme.navy),
            decoration: const InputDecoration(counterText: ''),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppTheme.textMid))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text('Confirm',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, color: AppTheme.navy))),
        ],
      ),
    );
  }

  /// Sends an SMS and completes with the verification id.
  static Future<String> _send({
    required String phone,
    MultiFactorSession? session,
    PhoneMultiFactorInfo? hint,
  }) {
    final c = Completer<String>();
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: hint == null ? phone : null,
      multiFactorSession: session,
      multiFactorInfo: hint,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!c.isCompleted) c.completeError(e);
      },
      codeSent: (id, _) {
        if (!c.isCompleted) c.complete(id);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return c.future;
  }

  /// Finishes a sign-in that needs the second step (SMS code).
  /// Returns the signed-in user, or null if the person cancelled.
  static Future<User?> resolveSignIn(
      BuildContext context, FirebaseAuthMultiFactorException e) async {
    final resolver = e.resolver;
    PhoneMultiFactorInfo? hint;
    for (final h in resolver.hints) {
      if (h is PhoneMultiFactorInfo) {
        hint = h;
        break;
      }
    }
    if (hint == null) {
      throw FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'No phone number is set up for 2-step verification.');
    }
    final id = await _send(
        phone: hint.phoneNumber, session: resolver.session, hint: hint);
    if (!context.mounted) return null;
    final code = await askCode(context, hint.phoneNumber);
    if (code == null || code.length != 6) return null;
    final cred = PhoneAuthProvider.credential(
        verificationId: id, smsCode: code);
    final result = await resolver
        .resolveSignIn(PhoneMultiFactorGenerator.getAssertion(cred));
    return result.user;
  }

  static Future<bool> hasSecondStep(User user) async =>
      (await user.multiFactor.getEnrolledFactors()).isNotEmpty;

  /// Adds the admin's phone as the second step. Returns true on success.
  static Future<bool> enroll(BuildContext context, String rawPhone,
      {String dial = '233'}) async {
    final user = FirebaseAuth.instance.currentUser!;
    final phone = normalize(rawPhone, dial: dial);
    if (!looksValid(phone)) {
      throw FirebaseAuthException(code: 'invalid-phone-number');
    }
    final session = await user.multiFactor.getSession();
    final id = await _send(phone: phone, session: session);
    if (!context.mounted) return false;
    final code = await askCode(context, phone);
    if (code == null || code.length != 6) return false;
    final cred =
        PhoneAuthProvider.credential(verificationId: id, smsCode: code);
    await user.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(cred),
        displayName: 'Admin phone');
    return true;
  }

  /// Shown once per session to the admin when 2-step is not set up yet.
  static bool _offered = false;
  static Future<void> offerAdminSetup(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _offered || await hasSecondStep(user)) return;
    _offered = true;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    var dial = '233';
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Secure your admin account',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppTheme.navy)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Add your phone number. After your password, you will enter '
              'a code sent by SMS each time you sign in.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textMid)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(color: AppTheme.navy),
            decoration: InputDecoration(
                hintText: dial == '44' ? '07123 456789' : '024 123 4567',
                prefixIcon: dialPicker(dial, (v) => setD(() => dial = v)),
                prefixIconConstraints: const BoxConstraints()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Not now',
                  style: GoogleFonts.poppins(color: AppTheme.textMid))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text('Send code',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, color: AppTheme.navy))),
        ],
      )),
    );
    if (phone == null || phone.isEmpty || !context.mounted) return;
    try {
      final ok = await enroll(context, phone, dial: dial);
      if (context.mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('2-step verification is on for the admin account.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendly(e))));
      }
      _offered = false;
    }
  }
}
