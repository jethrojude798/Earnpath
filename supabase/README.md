# EarnPath database foundation

This folder contains the Supabase/Postgres migrations for the EarnPath MVP. They establish the schema, row-level access controls, and realtime publication used by the chat integration.

## What it creates

- Freelancer and employer profiles, with account role chosen once at signup.
- Employer business profiles and verification state.
- Skills and user skill selections.
- Opportunities with a draft → review → publish workflow.
- Applications, saved opportunities, private conversations and messages.
- User blocks, reports, and two-party work records.
- Row Level Security policies for public content and authenticated users.
- Narrow database functions for opportunity review, application status changes, and work confirmation.

Signup profile creation reads `role` and `display_name` from Supabase Auth signup metadata. Only the two supported roles are accepted; any other role value falls back to `freelancer`. After signup, the database role is not writable by the client. Admin checks use the trusted JWT `app_metadata.role` claim, which must only be assigned through a trusted Supabase admin/server process.

## Apply it to a Supabase project

1. Create a Supabase project and keep its database password private.
2. Install or run the Supabase CLI, then open a terminal in the workspace folder.
3. Initialize Supabase locally if needed, preserving this existing `supabase/migrations` folder.
4. Sign in with the CLI and link the local folder to your project reference.
5. Review the SQL migration, then run `supabase db push --dry-run --remote` followed by `supabase db push --remote` to apply it.
6. In Supabase Auth, configure the signup providers and redirect URLs for your eventual web domain.
7. Create the first administrator through a trusted server/admin process that sets `app_metadata.role = "admin"`. Never set that claim from browser signup code.

The core migration `202611030001` was applied to the hosted project manually through the Dashboard SQL Editor. The local CLI is not linked. Apply `202611120001_enable_chat_realtime.sql` in the SQL Editor to enable realtime for conversations and messages. Because manual SQL Editor runs do not record migration history, before a future CLI `db push`, link the CLI and mark each manually applied version as applied with `supabase migration repair <version> --status applied --remote`. That command updates migration history only; it does not run SQL. Follow Supabase's current guides for [database migrations](https://supabase.com/docs/guides/deployment/database-migrations), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), and [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).

The preview uses the project's URL and public `anon` key in `outputs/supabase-config.js` for browser-side Supabase Auth and database access. Public keys are intended for browser clients; the secret/service-role key must never be placed in browser code. Set a valid Site URL and redirect allowlist under Supabase Auth URL settings before testing email confirmation. Account signup, profile roles, conversations, messages, user blocks, and chat reports use Supabase. Most other screens still use sample data.

## Important boundaries

- No NIN number, driver’s licence number, or identity image is stored in this schema. Add identity verification only after choosing a clear purpose, provider, retention policy, and access process.
- Profile photos need a Storage bucket and its own file-path policies. The schema stores only an optional `avatar_path`; it does not configure a bucket.
- Admin review, employer verification, notifications, and other privileged tasks require a trusted server action or Edge Function. Do not put the Supabase service-role key in the browser.
- Chat rows and account data become real personal data once connected. Add a privacy notice, deletion/export flows, spam controls, and a moderation process before opening signups broadly.
- The preview’s sample content is not seeded into the live database.

## Client integration still needed

The next implementation steps are to replace browser-local demo state in opportunities, applications, profile photos, saved items, and work-record screens with Supabase calls. The frontend should use only the project URL and public key; database policies remain the enforcement boundary.
