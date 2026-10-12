const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

const RESEND_API_KEY = defineSecret('RESEND_API_KEY');

// Change after verifying tehcs.com in Resend (see setup notes).
const FROM = 'TEHCS <noreply@tehcs.com>';
const CODE_MINUTES = 10;
const RESEND_SECONDS = 45;
const MAX_ATTEMPTS = 5;

const hashCode = (code, uid) =>
  crypto.createHash('sha256').update(`${code}:${uid}`).digest('hex');

function emailHtml(name, code) {
  return `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px;color:#1B2B5E">
  <h2 style="margin:0 0 8px">TEHCS</h2>
  <p>Hi ${name || 'there'}, use this code to verify your email:</p>
  <p style="font-size:34px;font-weight:800;letter-spacing:8px;margin:18px 0">${code}</p>
  <p style="color:#475569;font-size:13px">It expires in ${CODE_MINUTES} minutes. If you didn't create a TEHCS account, ignore this email.</p>
</div>`;
}

exports.sendOtp = onCall({ secrets: [RESEND_API_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const uid = req.auth.uid;
  const user = await admin.auth().getUser(uid);
  if (!user.email) throw new HttpsError('failed-precondition', 'No email on account.');
  if (user.emailVerified) return { alreadyVerified: true };

  const ref = db.collection('otp_codes').doc(uid);
  const snap = await ref.get();
  if (snap.exists) {
    const last = snap.data().sentAt?.toMillis?.() || 0;
    const wait = RESEND_SECONDS * 1000 - (Date.now() - last);
    if (wait > 0) {
      throw new HttpsError('resource-exhausted',
        `Please wait ${Math.ceil(wait / 1000)}s before requesting another code.`);
    }
  }

  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  await ref.set({
    hash: hashCode(code, uid),
    email: user.email,
    attempts: 0,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + CODE_MINUTES * 60 * 1000),
  });

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY.value().trim()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM,
      to: [user.email],
      subject: `${code} is your TEHCS verification code`,
      html: emailHtml(user.displayName, code),
    }),
  });
  if (!res.ok) {
    console.error('Resend error', res.status, await res.text());
    await ref.delete().catch(() => {});
    throw new HttpsError('internal', 'Could not send the email. Try again shortly.');
  }
  return { sent: true };
});

exports.verifyOtp = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const uid = req.auth.uid;
  const code = String(req.data?.code || '').trim();
  if (!/^\d{6}$/.test(code)) throw new HttpsError('invalid-argument', 'Enter the 6-digit code.');

  const ref = db.collection('otp_codes').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'No code requested. Tap Resend.');
  const d = snap.data();

  if (d.expiresAt.toMillis() < Date.now()) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'Code expired. Tap Resend.');
  }
  if (d.attempts >= MAX_ATTEMPTS) {
    await ref.delete();
    throw new HttpsError('resource-exhausted', 'Too many wrong tries. Tap Resend for a new code.');
  }
  if (hashCode(code, uid) !== d.hash) {
    await ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError('permission-denied', 'Incorrect code.');
  }

  await admin.auth().updateUser(uid, { emailVerified: true });
  await ref.delete();
  return { verified: true };
});

// ─────────────────────────────────────────────────────────
// PUSH NOTIFICATIONS
// ─────────────────────────────────────────────────────────
// Must match your Firestore database location (us-central1 = nam5 / us-central).
// If the deploy complains about the region, change it to the one it names.
const FIRESTORE_REGION = 'us-central1';
const ADMIN_EMAIL = 'twitchempireinfo@gmail.com';

async function tokensForEmails(emails) {
  const out = new Set();
  for (let i = 0; i < emails.length; i += 30) {
    const chunk = emails.slice(i, i + 30);
    const snap = await db.collection('device_tokens').where('email', 'in', chunk).get();
    snap.forEach((d) => (d.data().tokens || []).forEach((t) => out.add(t)));
  }
  return [...out];
}

async function sendPush(tokens, title, body, data = {}) {
  if (!tokens.length) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    android: { priority: 'high' },
  });
  // Remove tokens that no longer work.
  const dead = [];
  res.responses.forEach((r, i) => {
    const c = r.error && r.error.code;
    if (!r.success && (c === 'messaging/registration-token-not-registered' ||
                       c === 'messaging/invalid-registration-token')) dead.push(tokens[i]);
  });
  for (const t of dead) {
    const snap = await db.collection('device_tokens').where('tokens', 'array-contains', t).get();
    await Promise.all(snap.docs.map((d) =>
      d.ref.update({ tokens: admin.firestore.FieldValue.arrayRemove(t) })));
  }
}

// A client books -> push to matching staff + admin.
exports.onBookingCreated = onDocumentCreated(
  { document: 'bookings/{id}', region: FIRESTORE_REGION },
  async (event) => {
    const b = event.data && event.data.data();
    if (!b) return;
    const category = b.category || '';
    let q = db.collection('staff_by_email');
    if (category) q = q.where('category', '==', category);
    const staff = await q.get();
    const emails = staff.docs.map((d) => d.id.toLowerCase());
    emails.push(ADMIN_EMAIL);
    const tokens = await tokensForEmails([...new Set(emails)]);
    await sendPush(
      tokens,
      `New booking: ${b.service || 'Service'}`,
      `${b.clientName || 'A client'} \u2022 ${b.date || ''} ${b.time || ''}`.trim(),
      { type: 'new_booking', bookingId: event.params.id },
    );
  },
);

// Staff accepted a job / clocked in -> push to admin.
exports.onAdminNotification = onDocumentCreated(
  { document: 'notifications/{id}', region: FIRESTORE_REGION },
  async (event) => {
    const n = event.data && event.data.data();
    if (!n || !n.forAdmin) return;
    const tokens = await tokensForEmails([ADMIN_EMAIL]);
    await sendPush(tokens, n.title || 'TEHCS update', n.body || '', { type: n.type || '' });
  },
);
