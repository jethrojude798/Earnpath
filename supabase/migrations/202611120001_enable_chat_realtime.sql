-- Enable Supabase Realtime events for the chat inbox and message thread.
-- The existing Row Level Security policies continue to limit which rows
-- each signed-in participant can read.
do $$
begin
  create unique index if not exists conversations_general_pair_unique
    on public.conversations (freelancer_id, employer_id)
    where opportunity_id is null;

  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'The supabase_realtime publication is not available in this project.';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    execute 'alter publication supabase_realtime add table public.conversations';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    execute 'alter publication supabase_realtime add table public.messages';
  end if;
end;
$$;
