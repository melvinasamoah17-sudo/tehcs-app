const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');
const zlib = require('zlib');

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

// ─────────────────────────────────────────────────────────
// VOICE / VIDEO CALLS (Agora)
// ─────────────────────────────────────────────────────────
// Set once with:
//   firebase functions:secrets:set AGORA_APP_ID
//   firebase functions:secrets:set AGORA_APP_CERTIFICATE
const AGORA_APP_ID = defineSecret('AGORA_APP_ID');
const AGORA_APP_CERTIFICATE = defineSecret('AGORA_APP_CERTIFICATE');
const CALL_TOKEN_SECONDS = 2 * 60 * 60; // a call can last up to 2 hours

// Agora AccessToken2 ("007") for RTC, built with Node's own crypto/zlib so
// no extra npm package is needed. Same format as agora-token's
// RtcTokenBuilder.buildTokenWithUid(..., RtcRole.PUBLISHER, ...).
function buildAgoraRtcToken(appId, appCert, channel, uid, expireSeconds) {
  const u16 = (n) => { const b = Buffer.alloc(2); b.writeUInt16LE(n); return b; };
  const u32 = (n) => { const b = Buffer.alloc(4); b.writeUInt32LE(n >>> 0); return b; };
  const str = (v) => {
    const b = Buffer.isBuffer(v) ? v : Buffer.from(String(v), 'utf8');
    return Buffer.concat([u16(b.length), b]);
  };
  const hmac = (key, msg) => crypto.createHmac('sha256', key).update(msg).digest();

  const issueTs = Math.floor(Date.now() / 1000);
  const salt = crypto.randomInt(1, 99999999);
  // Privileges: 1 join channel, 2 publish audio, 3 publish video, 4 publish data.
  const privileges = [1, 2, 3, 4];
  const rtcService = Buffer.concat([
    u16(1), // service type: RTC
    u16(privileges.length),
    ...privileges.flatMap((p) => [u16(p), u32(expireSeconds)]),
    str(channel),
    str(uid === 0 ? '' : String(uid)),
  ]);
  const signingInfo = Buffer.concat([
    str(appId), u32(issueTs), u32(expireSeconds), u32(salt), u16(1), rtcService,
  ]);
  let signing = hmac(u32(issueTs), appCert);
  signing = hmac(u32(salt), signing);
  const signature = hmac(signing, signingInfo);
  const content = Buffer.concat([str(signature), signingInfo]);
  return '007' + zlib.deflateSync(content).toString('base64');
}

// Returns what the app needs to join the Agora channel for a call it is part of.
exports.getAgoraToken = onCall(
  { secrets: [AGORA_APP_ID, AGORA_APP_CERTIFICATE] },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
    const callId = String(req.data?.callId || '');
    if (!callId) throw new HttpsError('invalid-argument', 'Missing callId.');

    const snap = await db.collection('calls').doc(callId).get();
    if (!snap.exists) throw new HttpsError('not-found', 'Call not found.');
    const c = snap.data();
    if (!['ringing', 'accepted'].includes(c.status)) {
      throw new HttpsError('failed-precondition', 'This call has ended.');
    }

    const uid = req.auth.uid;
    const email = (req.auth.token.email || '').toLowerCase();
    const isCaller = c.callerUid === uid;
    const isCallee = c.calleeUid === uid || (c.toAdmin === true && email === ADMIN_EMAIL);
    if (!isCaller && !isCallee) {
      throw new HttpsError('permission-denied', 'You are not part of this call.');
    }

    const agoraUid = isCaller ? 1 : 2;
    const appId = AGORA_APP_ID.value().trim();
    const token = buildAgoraRtcToken(
      appId, AGORA_APP_CERTIFICATE.value().trim(), callId, agoraUid, CALL_TOKEN_SECONDS);
    return { appId, token, uid: agoraUid, channel: callId };
  },
);

// New call -> push to whoever is being called, so a backgrounded phone
// shows "Incoming call"; opening the app while it's ringing shows the call.
exports.onCallCreated = onDocumentCreated(
  { document: 'calls/{id}', region: FIRESTORE_REGION },
  async (event) => {
    const c = event.data && event.data.data();
    if (!c || c.status !== 'ringing') return;
    let tokens = [];
    if (c.toAdmin) {
      tokens = await tokensForEmails([ADMIN_EMAIL]);
    } else if (c.calleeUid) {
      const d = await db.collection('device_tokens').doc(c.calleeUid).get();
      tokens = (d.exists && d.data().tokens) || [];
    }
    await sendPush(
      tokens,
      c.video ? 'Incoming video call' : 'Incoming voice call',
      `${c.callerName || 'Someone'} is calling you on TEHCS`,
      { type: 'call', callId: event.params.id },
    );
  },
);
