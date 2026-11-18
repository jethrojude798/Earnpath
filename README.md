# EarnPath

EarnPath is a responsive Nigerian skills-to-income platform preview for freelancers and employers. The current app is a single-page web interface in `outputs/` with Supabase Auth and database-backed messaging.

## Run the preview

Serve the `outputs/` folder with any local static web server, then open its URL in a browser. The preview expects the Supabase project URL and public client key in `outputs/supabase-config.js`.

## Supabase setup

The database scripts are in `supabase/migrations/` and should be applied in filename order:

1. `202611030001_earnpath_core.sql` creates the core schema and Row Level Security policies.
2. `202611120001_enable_chat_realtime.sql` enables realtime updates for conversations and messages.

Configure Supabase Auth's Site URL and redirect allowlist to match the address used to serve the app. For another Supabase project, update `outputs/supabase-config.js` with that project's URL and public `anon` or publishable key. Never put a `service_role` or secret key in browser code.

## Current scope

Email/password account creation and sign-in use Supabase Auth. Freelancer and employer roles are saved to profiles. Conversations and messages are saved in Supabase; the database policies restrict access to conversation participants. Listings, applications, saved opportunities, work records, profile photos, and most other screens remain previews or local demonstrations.

See `outputs/README.md` and `supabase/README.md` for more details.
