# Talend X — Firebase-to-Supabase Migration Architecture & Blocker Status

## 1. Current Inventory (Audited Across 52 Dart Files)
- **Files with direct Firebase imports/calls:** `34 / 52` files in `lib/` (`firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`).
- **Firestore collections referenced (17):** `users`, `favorites`, `messages`, `connections`, `sessions`, `reviews`, `notifications`, `communities`, `community_members`, `community_posts`, `resources`, `wallets`, `transactions`, `paymentMethods`, `referrals`, `reports`, `blocked_users`.
- **Existing production Firebase dataset (`talendx-12808`) exported & backed up:**
  - `21` Firebase Auth users
  - `26` `users` documents
  - `1` `favorites` document
  - `10` `messages` documents

## 2. Prepared Supabase Migration Artifacts
- **PostgreSQL Schema + RLS:** `supabase/migrations/001_initial_schema.sql` (all 17 tables, foreign keys, indexes, `updated_at` triggers, and strict `auth.uid()` / `is_admin_user()` RLS policies).
- **Idempotent Data Migration Script:** `supabase/migrate_from_firebase.mjs` (imports Auth users preserving `email` & `email_verified`, maps `firebase_uid` → `supabase_uuid`, and upserts profiles, favorites, and messages).
- **Existing-User Password Strategy:** Firebase password hashes are not exported; migrated users establish their Supabase password via `supabase.auth.resetPasswordForEmail()` ("Forgot Password") on first sign-in.

## 3. Current Project Provisioning Blocker
- Creating a dedicated Talend X Supabase project in organization `kofelbcwdkuycbytmsjj` returned:
  > `free_project_limit`: `domaduiosyousf44@gmail.com (2 project limit)` (active projects: `Portfolio` `wwxapgrgjsyzpyhazser` and `ieee-iu-join` `gvlqdckrmfcxwuadrikw`).
- Per security/isolation rules, the Portfolio Supabase project (`wwxapgrgjsyzpyhazser`) is **not** reused for Talend X, and the working Firebase app (`talendx-12808`) is preserved intact until a dedicated Talend X Supabase project is provisioned.

## 4. Rollback Plan
- Firebase project `talendx-12808` and all Firestore collections remain untouched.
- Previous Android releases `v1.0.0` and `v1.0.1` remain preserved on GitHub Releases.
