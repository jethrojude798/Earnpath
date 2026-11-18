-- EarnPath MVP database foundation for Supabase.
-- Government identity numbers and identity document images are intentionally excluded.

create type public.account_role as enum ('freelancer', 'employer');
create type public.verification_state as enum ('unverified', 'pending', 'verified', 'rejected');
create type public.opportunity_kind as enum ('job', 'paid_project', 'internship', 'apprenticeship', 'service');
create type public.opportunity_state as enum ('draft', 'pending_review', 'published', 'closed', 'rejected');
create type public.application_state as enum ('submitted', 'shortlisted', 'accepted', 'declined', 'withdrawn');
create type public.report_target_kind as enum ('profile', 'opportunity', 'message');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.account_role not null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  bio text not null default '' check (char_length(bio) <= 1200),
  city text check (char_length(city) <= 100),
  state text check (char_length(state) <= 100),
  avatar_path text,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.employer_profiles (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  business_name text not null check (char_length(business_name) between 1 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  website text check (website is null or char_length(website) <= 300),
  verification public.verification_state not null default 'unverified',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.skills (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 1 and 80),
  category text not null check (char_length(category) between 1 and 80),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profile_skills (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(user_id) on delete restrict,
  title text not null check (char_length(title) between 5 and 140),
  description text not null check (char_length(description) between 20 and 8000),
  kind public.opportunity_kind not null,
  compensation_text text not null check (char_length(compensation_text) between 1 and 160),
  work_arrangement text not null default 'unspecified' check (work_arrangement in ('remote', 'hybrid', 'onsite', 'unspecified')),
  city text,
  state text,
  deadline timestamptz,
  status public.opportunity_state not null default 'draft',
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.opportunity_skills (
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete restrict,
  primary key (opportunity_id, skill_id)
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  freelancer_id uuid not null references public.profiles(user_id) on delete restrict,
  message text not null default '' check (char_length(message) <= 3000),
  status public.application_state not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (opportunity_id, freelancer_id)
);

create table public.saved_opportunities (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, opportunity_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  freelancer_id uuid not null references public.profiles(user_id) on delete cascade,
  employer_id uuid not null references public.profiles(user_id) on delete cascade,
  opportunity_id uuid references public.opportunities(id) on delete set null,
  created_at timestamptz not null default now(),
  check (freelancer_id <> employer_id),
  unique (freelancer_id, employer_id, opportunity_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(user_id) on delete restrict,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(user_id) on delete cascade,
  blocked_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(user_id) on delete restrict,
  target_kind public.report_target_kind not null,
  target_id uuid not null,
  reason text not null check (char_length(reason) between 3 and 120),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

create table public.work_records (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid references public.opportunities(id) on delete set null,
  employer_id uuid not null references public.profiles(user_id) on delete restrict,
  freelancer_id uuid not null references public.profiles(user_id) on delete restrict,
  summary text not null check (char_length(summary) between 5 and 500),
  employer_confirmed_at timestamptz,
  freelancer_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  check (employer_id <> freelancer_id)
);

create index opportunities_public_search_idx on public.opportunities (status, created_at desc);
create index opportunities_employer_idx on public.opportunities (employer_id, created_at desc);
create index applications_freelancer_idx on public.applications (freelancer_id, created_at desc);
create index messages_conversation_idx on public.messages (conversation_id, created_at);
create index reports_queue_idx on public.reports (status, created_at desc);
create index work_records_parties_idx on public.work_records (employer_id, freelancer_id);

-- The account role is taken from signup metadata once, validated, then stored in profiles.
-- Do not use user-editable metadata for authorization after account creation.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_role public.account_role;
  chosen_name text;
begin
  chosen_role := case
    when new.raw_user_meta_data ->> 'role' = 'employer' then 'employer'::public.account_role
    else 'freelancer'::public.account_role
  end;
  chosen_name := nullif(trim(new.raw_user_meta_data ->> 'display_name'), '');
  if chosen_name is null then chosen_name := coalesce(nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'EarnPath member'); end if;
  insert into public.profiles (user_id, role, display_name)
  values (new.id, chosen_role, left(chosen_name, 80));
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger employer_profiles_set_updated_at before update on public.employer_profiles
  for each row execute function public.set_updated_at();
create trigger opportunities_set_updated_at before update on public.opportunities
  for each row execute function public.set_updated_at();
create trigger applications_set_updated_at before update on public.applications
  for each row execute function public.set_updated_at();

create function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role' = 'admin', false)
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

create function public.are_users_blocked(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (auth.uid() = p_first or auth.uid() = p_second)
    and exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = p_first and b.blocked_id = p_second)
          or (b.blocker_id = p_second and b.blocked_id = p_first)
    )
$$;
revoke all on function public.are_users_blocked(uuid, uuid) from public, anon;
grant execute on function public.are_users_blocked(uuid, uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.employer_profiles enable row level security;
alter table public.skills enable row level security;
alter table public.profile_skills enable row level security;
alter table public.opportunities enable row level security;
alter table public.opportunity_skills enable row level security;
alter table public.applications enable row level security;
alter table public.saved_opportunities enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.user_blocks enable row level security;
alter table public.reports enable row level security;
alter table public.work_records enable row level security;

-- Profiles contain only fields intended for profile display; email and identity data stay in Auth/provider systems.
create policy "Public profiles are visible; owners see their own" on public.profiles
  for select to anon, authenticated using (is_public or user_id = (select auth.uid()) or (select public.is_admin()));
create policy "Users update their own profile" on public.profiles
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Employer profiles are readable with public profiles" on public.employer_profiles
  for select to anon, authenticated using (
    exists (select 1 from public.profiles p where p.user_id = employer_profiles.user_id and (p.is_public or p.user_id = (select auth.uid())))
    or (select public.is_admin())
  );
create policy "Employers create their business profile" on public.employer_profiles
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.role = 'employer')
  );
create policy "Employers edit their business profile" on public.employer_profiles
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Active skills are readable" on public.skills
  for select to anon, authenticated using (is_active or (select public.is_admin()));
create policy "Users manage their skill selections" on public.profile_skills
  for all to authenticated using (user_id = (select auth.uid()) or (select public.is_admin()))
  with check (user_id = (select auth.uid()) or (select public.is_admin()));

create policy "Published opportunities are public; owners see their listings" on public.opportunities
  for select to anon, authenticated using (status = 'published' or employer_id = (select auth.uid()) or (select public.is_admin()));
create policy "Employers create their own drafts" on public.opportunities
  for insert to authenticated with check (
    employer_id = (select auth.uid()) and status = 'draft'
    and exists (select 1 from public.profiles p where p.user_id = employer_id and p.role = 'employer')
  );
create policy "Employers edit their own drafts" on public.opportunities
  for update to authenticated using (employer_id = (select auth.uid()) and status = 'draft')
  with check (employer_id = (select auth.uid()) and status = 'draft');
create policy "Employers delete their own drafts" on public.opportunities
  for delete to authenticated using (employer_id = (select auth.uid()) and status = 'draft');
create policy "Opportunity skills follow visible opportunity" on public.opportunity_skills
  for select to anon, authenticated using (exists (select 1 from public.opportunities o where o.id = opportunity_id and (o.status = 'published' or o.employer_id = (select auth.uid()))));
create policy "Employer edits skills on own draft" on public.opportunity_skills
  for all to authenticated using (exists (select 1 from public.opportunities o where o.id = opportunity_id and o.employer_id = (select auth.uid()) and o.status = 'draft'))
  with check (exists (select 1 from public.opportunities o where o.id = opportunity_id and o.employer_id = (select auth.uid()) and o.status = 'draft'));

create policy "Freelancers view their applications; employers view applications to their listings" on public.applications
  for select to authenticated using (
    freelancer_id = (select auth.uid())
    or exists (select 1 from public.opportunities o where o.id = opportunity_id and o.employer_id = (select auth.uid()))
    or (select public.is_admin())
  );
create policy "Freelancers apply to published opportunities" on public.applications
  for insert to authenticated with check (
    freelancer_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.user_id = freelancer_id and p.role = 'freelancer')
    and exists (select 1 from public.opportunities o where o.id = opportunity_id and o.status = 'published')
  );

create policy "Users manage their saved opportunities" on public.saved_opportunities
  for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Conversation participants can read conversations" on public.conversations
  for select to authenticated using (freelancer_id = (select auth.uid()) or employer_id = (select auth.uid()) or (select public.is_admin()));
create policy "A freelancer or employer can start a conversation" on public.conversations
  for insert to authenticated with check (
    not public.are_users_blocked(freelancer_id, employer_id)
    and
    ((freelancer_id = (select auth.uid())
      and exists (select 1 from public.profiles p where p.user_id = freelancer_id and p.role = 'freelancer')
      and exists (select 1 from public.profiles p where p.user_id = employer_id and p.role = 'employer'))
    or (employer_id = (select auth.uid())
      and exists (select 1 from public.profiles p where p.user_id = employer_id and p.role = 'employer')
      and exists (select 1 from public.profiles p where p.user_id = freelancer_id and p.role = 'freelancer')))
  );
create policy "Conversation participants can read messages" on public.messages
  for select to authenticated using (exists (
    select 1 from public.conversations c where c.id = conversation_id
    and ((c.freelancer_id = (select auth.uid())) or (c.employer_id = (select auth.uid())))
  ) or (select public.is_admin()));
create policy "Participants send messages as themselves" on public.messages
  for insert to authenticated with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.conversations c where c.id = conversation_id
      and ((c.freelancer_id = (select auth.uid())) or (c.employer_id = (select auth.uid())))
      and not public.are_users_blocked(c.freelancer_id, c.employer_id)
    )
  );

create policy "Users see blocks they created" on public.user_blocks
  for select to authenticated using (blocker_id = (select auth.uid()));
create policy "Users block others" on public.user_blocks
  for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy "Users remove their blocks" on public.user_blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

create policy "Reporters create reports and admins review them" on public.reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "Reporters see their reports; admins see all" on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()) or (select public.is_admin()));

create policy "Parties can read their work records" on public.work_records
  for select to authenticated using (employer_id = (select auth.uid()) or freelancer_id = (select auth.uid()) or (select public.is_admin()));
create policy "Employers initiate work records for freelancers" on public.work_records
  for insert to authenticated with check (
    employer_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.user_id = employer_id and p.role = 'employer')
    and exists (select 1 from public.profiles p where p.user_id = freelancer_id and p.role = 'freelancer')
  );

-- Expose only the columns required for MVP client operations. Sensitive workflow fields
-- (verification, moderation status, application status, report status, confirmations)
-- are intentionally not writable by normal clients and need trusted server actions.
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.employer_profiles, public.skills, public.profile_skills,
  public.opportunities, public.opportunity_skills to anon, authenticated;
grant update (display_name, bio, city, state, avatar_path, is_public) on public.profiles to authenticated;
grant insert (user_id, business_name, description, website) on public.employer_profiles to authenticated;
grant update (business_name, description, website) on public.employer_profiles to authenticated;
grant insert (employer_id, title, description, kind, compensation_text, work_arrangement, city, state, deadline)
  on public.opportunities to authenticated;
grant update (title, description, kind, compensation_text, work_arrangement, city, state, deadline)
  on public.opportunities to authenticated;
grant delete on public.opportunities to authenticated;
grant insert, delete on public.profile_skills to authenticated;
grant insert, delete on public.opportunity_skills to authenticated;
grant select on public.applications to authenticated;
grant insert (opportunity_id, freelancer_id, message) on public.applications to authenticated;
grant select, insert, delete on public.saved_opportunities to authenticated;
grant select on public.conversations, public.messages to authenticated;
grant insert (freelancer_id, employer_id, opportunity_id) on public.conversations to authenticated;
grant insert (conversation_id, sender_id, body) on public.messages to authenticated;
grant select, insert, delete on public.user_blocks to authenticated;
grant select on public.reports, public.work_records to authenticated;
grant insert (reporter_id, target_kind, target_id, reason, details) on public.reports to authenticated;
grant insert (opportunity_id, employer_id, freelancer_id, summary) on public.work_records to authenticated;

insert into public.skills (name, category) values
  ('Software development', 'Technology'),
  ('Data analysis', 'Technology'),
  ('Cybersecurity', 'Technology'),
  ('Graphic design', 'Digital and Creative Skills'),
  ('Digital marketing', 'Digital and Creative Skills'),
  ('Photography', 'Photography and Media'),
  ('Tailoring', 'Fashion and Beauty Services'),
  ('Baking', 'Vocational and Technical Trades'),
  ('Electrical repair', 'Repairs and Maintenance'),
  ('Administration', 'Business and Administration')
on conflict (name) do nothing;

-- Safe state transitions are exposed as narrowly scoped RPCs instead of allowing
-- clients to write moderation, review or confirmation fields directly.
create function public.submit_opportunity_for_review(p_opportunity_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.opportunities
     set status = 'pending_review', updated_at = now()
   where id = p_opportunity_id and employer_id = auth.uid() and status = 'draft';
  if not found then raise exception 'Draft opportunity not found or not owned by you'; end if;
end;
$$;
revoke all on function public.submit_opportunity_for_review(uuid) from public, anon;
grant execute on function public.submit_opportunity_for_review(uuid) to authenticated;

create function public.review_opportunity(p_opportunity_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'Administrator access required'; end if;
  update public.opportunities
     set status = case when p_approve then 'published'::public.opportunity_state else 'rejected'::public.opportunity_state end,
         reviewed_at = now(), updated_at = now()
   where id = p_opportunity_id and status = 'pending_review';
  if not found then raise exception 'Opportunity is not awaiting review'; end if;
end;
$$;
revoke all on function public.review_opportunity(uuid, boolean) from public, anon;
grant execute on function public.review_opportunity(uuid, boolean) to authenticated;

create function public.update_application_status(p_application_id uuid, p_status public.application_state)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_status public.application_state;
begin
  select a.status into current_status
    from public.applications a
    join public.opportunities o on o.id = a.opportunity_id
   where a.id = p_application_id
     and (a.freelancer_id = auth.uid() or o.employer_id = auth.uid())
   for update of a;
  if not found then raise exception 'Application not found or not accessible'; end if;

  if exists (select 1 from public.applications a where a.id = p_application_id and a.freelancer_id = auth.uid()) then
    if p_status <> 'withdrawn' or current_status not in ('submitted', 'shortlisted') then
      raise exception 'Freelancers may only withdraw submitted or shortlisted applications';
    end if;
  else
    if p_status not in ('shortlisted', 'accepted', 'declined') or current_status not in ('submitted', 'shortlisted') then
      raise exception 'Employer cannot apply that status change';
    end if;
  end if;

  update public.applications set status = p_status, updated_at = now() where id = p_application_id;
end;
$$;
revoke all on function public.update_application_status(uuid, public.application_state) from public, anon;
grant execute on function public.update_application_status(uuid, public.application_state) to authenticated;

create function public.confirm_work_record(p_work_record_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.work_records
     set employer_confirmed_at = case when employer_id = auth.uid() then coalesce(employer_confirmed_at, now()) else employer_confirmed_at end,
         freelancer_confirmed_at = case when freelancer_id = auth.uid() then coalesce(freelancer_confirmed_at, now()) else freelancer_confirmed_at end
   where id = p_work_record_id and (employer_id = auth.uid() or freelancer_id = auth.uid());
  if not found then raise exception 'Work record not found or not accessible'; end if;
end;
$$;
revoke all on function public.confirm_work_record(uuid) from public, anon;
grant execute on function public.confirm_work_record(uuid) to authenticated;
