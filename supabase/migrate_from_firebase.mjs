/**
 * Talend X — Idempotent Firebase-to-Supabase Data Migration Script
 *
 * Usage:
 *   SUPABASE_URL=https://<your-talendx-ref>.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
 *   FIREBASE_BACKUP_JSON=./firebase_backup_talendx.json \
 *   node supabase/migrate_from_firebase.mjs
 *
 * Notes:
 * - Never commit SUPABASE_SERVICE_ROLE_KEY or firebase_backup_talendx.json.
 * - Existing Firebase users are imported into Supabase Auth with email_confirm: true
 *   and NO plaintext/invented password; existing users establish their Supabase password
 *   via "Forgot Password" (resetPasswordForEmail) on first sign-in.
 */
import fs from 'node:fs';
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const backupPath = process.env.FIREBASE_BACKUP_JSON;

if (!url || !serviceKey || !backupPath) {
  console.error('Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or FIREBASE_BACKUP_JSON');
  process.exit(1);
}

const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });
const backup = JSON.parse(fs.readFileSync(backupPath, 'utf8'));

const uidMap = new Map();

// 1. Migrate Firebase Auth users -> Supabase Auth (preserving email & verification)
const { data: existingAuthList } = await supabase.auth.admin.listUsers({ perPage: 1000 });
const byEmail = new Map((existingAuthList?.users || []).map((u) => [u.email?.toLowerCase(), u]));

for (const fu of backup.authUsers) {
  if (!fu.email) continue;
  const key = fu.email.toLowerCase();
  let sbUser = byEmail.get(key);
  if (!sbUser) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: fu.email,
      email_confirm: Boolean(fu.emailVerified),
      user_metadata: {
        name: fu.displayName || '',
        firebase_uid: fu.uid,
        migrated_from_firebase: true,
      },
    });
    if (error) {
      console.error('Auth createUser failed:', fu.email, error.message);
      continue;
    }
    sbUser = data.user;
    byEmail.set(key, sbUser);
  }
  uidMap.set(fu.uid, sbUser.id);
}
console.log('Mapped Auth users:', uidMap.size);

// Build legacy UID fallback map (for superseded Firestore user docs whose email matches an active Auth user)
const legacyUidMap = new Map(uidMap);
for (const doc of backup.collections.users || []) {
  if (!legacyUidMap.has(doc.id) && doc.email) {
    const sbUser = byEmail.get(doc.email.toLowerCase());
    if (sbUser) {
      legacyUidMap.set(doc.id, sbUser.id);
    }
  }
}

// 2. Migrate public.users profiles (only active Auth UIDs; legacy duplicates & deleted-Auth orphans are skipped)
let userCount = 0;
let userSkippedLegacy = 0;
let userSkippedOrphan = 0;
let userFailed = 0;
for (const doc of backup.collections.users || []) {
  const sbId = uidMap.get(doc.id);
  if (!sbId) {
    if (legacyUidMap.has(doc.id)) userSkippedLegacy++;
    else userSkippedOrphan++;
    continue;
  }
  const { error } = await supabase.from('users').upsert({
    id: sbId,
    firebase_uid: doc.id,
    email: doc.email || '',
    name: doc.name || '',
    faculty: doc.faculty || '',
    bio: doc.bio || '',
    phone: doc.phone || '',
    role: doc.role === 'admin' ? 'admin' : 'user',
    is_admin: Boolean(doc.isAdmin),
    preference: doc.preference || 'both',
    profile_completed: Boolean(doc.profileCompleted),
    email_verified: Boolean(doc.emailVerified),
    availability: doc.availability || {},
    teach_skills: Array.isArray(doc.teachSkills) ? doc.teachSkills : [],
    learn_skills: Array.isArray(doc.learnSkills) ? doc.learnSkills : [],
    recent_searches: Array.isArray(doc.recentSearches) ? doc.recentSearches : [],
  });
  if (error) userFailed++;
  else userCount++;
}
console.log('Migrated user profiles:', { source: (backup.collections.users || []).length, imported: userCount, skippedLegacyDup: userSkippedLegacy, skippedOrphanNoAuth: userSkippedOrphan, failed: userFailed });

// 3. Migrate favorites (using legacyUidMap so superseded UIDs resolve to active Supabase UUIDs)
let favCount = 0;
let favSkipped = 0;
let favFailed = 0;
for (const doc of backup.collections.favorites || []) {
  const uId = legacyUidMap.get(doc.userId);
  const fId = legacyUidMap.get(doc.favoriteUserId);
  if (!uId || !fId) {
    favSkipped++;
    continue;
  }
  const { error } = await supabase
    .from('favorites')
    .upsert({ user_id: uId, favorite_user_id: fId }, { onConflict: 'user_id,favorite_user_id' });
  if (error) {
    console.error('Favorite error:', error.message);
    favFailed++;
  } else {
    favCount++;
  }
}
console.log('Migrated favorites:', { source: (backup.collections.favorites || []).length, imported: favCount, skipped: favSkipped, failed: favFailed });

// 4. Migrate messages idempotently (preserving created_at, resolving legacy UIDs by email)
let msgInserted = 0;
let msgAlreadyPresent = 0;
let msgSkipped = 0;
let msgFailed = 0;

const { data: existingMsgs } = await supabase.from('messages').select('id, sender_id, receiver_id, content');
const existingMsgKeys = new Set(
  (existingMsgs || []).map((m) => `${m.sender_id}|${m.receiver_id}|${m.content}`)
);

for (const doc of backup.collections.messages || []) {
  const sId = legacyUidMap.get(doc.senderId);
  const rId = legacyUidMap.get(doc.receiverId);
  if (!sId || !rId || !doc.content) {
    msgSkipped++;
    continue;
  }
  const key = `${sId}|${rId}|${doc.content}`;
  if (existingMsgKeys.has(key)) {
    msgAlreadyPresent++;
    continue;
  }
  const createdAt = doc.createdAt?._seconds
    ? new Date(doc.createdAt._seconds * 1000).toISOString()
    : new Date().toISOString();
  const { error } = await supabase.from('messages').insert({
    sender_id: sId,
    receiver_id: rId,
    content: doc.content,
    read: Boolean(doc.read),
    created_at: createdAt,
  });
  if (error) {
    console.error('Message error:', doc.id, error.message);
    msgFailed++;
  } else {
    existingMsgKeys.add(key);
    msgInserted++;
  }
}
console.log('Migrated messages:', {
  source: (backup.collections.messages || []).length,
  newlyInserted: msgInserted,
  alreadyPresent: msgAlreadyPresent,
  totalInSupabase: msgInserted + msgAlreadyPresent,
  skippedNoAuthUser: msgSkipped,
  failed: msgFailed,
});
