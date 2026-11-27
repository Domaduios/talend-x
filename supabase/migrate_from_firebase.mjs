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
  }
  uidMap.set(fu.uid, sbUser.id);
}
console.log('Mapped Auth users:', uidMap.size);

// 2. Migrate public.users profiles
let userCount = 0;
for (const doc of backup.collections.users || []) {
  const sbId = uidMap.get(doc.id);
  if (!sbId) continue;
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
  if (!error) userCount++;
}
console.log('Migrated user profiles:', userCount);

// 3. Migrate favorites
let favCount = 0;
for (const doc of backup.collections.favorites || []) {
  const uId = uidMap.get(doc.userId);
  const fId = uidMap.get(doc.favoriteUserId);
  if (!uId || !fId) continue;
  const { error } = await supabase.from('favorites').upsert({ user_id: uId, favorite_user_id: fId });
  if (!error) favCount++;
}
console.log('Migrated favorites:', favCount);

// 4. Migrate messages
let msgCount = 0;
for (const doc of backup.collections.messages || []) {
  const sId = uidMap.get(doc.senderId);
  const rId = uidMap.get(doc.receiverId);
  if (!sId || !rId || !doc.content) continue;
  const { error } = await supabase.from('messages').insert({
    sender_id: sId,
    receiver_id: rId,
    content: doc.content,
    read: Boolean(doc.read),
  });
  if (!error) msgCount++;
}
console.log('Migrated messages:', msgCount);
