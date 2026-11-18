# EarnPath preview

This folder contains a responsive, interactive front-end preview of EarnPath.

## Open it

Open [the local preview](http://localhost:8765/) in a modern browser while the preview server is running. Auth redirect URLs use this local address. The font may fall back to a system font when offline.

## Included

- Learner overview and next-step dashboard.
- Skill category discovery and opportunity search.
- Opportunity search with type and skill-category filters.
- Application tracking with browser-local demo state.
- Portfolio project and employer listing forms.
- Employer workspace with opportunity drafting screens.
- Signup role selection for Freelancer or Employer, with role-specific workspaces.
- Supabase email/password signup and sign-in with role/profile persistence.
- Profile photo selection and in-session crop/zoom controls before and after signup.
- Role-aware messaging with Supabase conversations, saved messages, member search, blocking, reporting, and realtime updates.
- Header light/dark theme toggle with browser-local preference.
- Opportunity detail views with compensation, arrangement, deadline, save and report actions.
- Help and safety guidance, sample reports, and two-party work-record confirmation screens.
- Mobile navigation and responsive layouts.

All example opportunities and review records are explicitly marked as samples. Applications, saved items, work records, listings, and profile photos remain local demonstrations only. Conversations, messages, blocks, and chat profile reports are stored in Supabase for signed-in members.

Government ID is not requested or stored by signup. Identity verification can be designed separately if EarnPath establishes a clear need and secure process.

Profile photos are demo-only. Photo previews last for the current browser session and are not uploaded to Supabase.

## Before a real launch

The source brief specifies React, TypeScript, Tailwind, and Supabase. The current deliverable remains a single-file front-end preview. Supabase migrations and setup notes are in the workspace's `supabase` folder. Signup and sign-in use Supabase Auth and persist role/profile data. Messages, conversations, blocks, and chat reports use Supabase. Opportunities, applications, saved items, work records, and profile photos remain demo-only. Email confirmation requires a valid Site URL and redirect URL in Supabase Auth settings. See `supabase/README.md` for setup and scope. Before publishing, add private storage rules, trusted server functions for moderation, and complete the remaining data integrations.

Never put a Supabase service-role key in browser code. Keep the demo content clearly separate from real, reviewed opportunities.
