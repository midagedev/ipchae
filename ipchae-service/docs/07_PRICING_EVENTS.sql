-- IPCHAE Pricing Events (Free-first growth analytics)

create table if not exists public.pricing_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('paywall_viewed', 'paywall_dismissed', 'upgrade_clicked', 'trial_started', 'upgrade_completed')),
  tier text not null check (tier in ('free', 'plus', 'team')),
  trigger_event text not null check (trigger_event in ('createShareLink', 'exportAdvancedFormat', 'inviteCollaborator', 'restoreOldVersion')),
  reason_code text not null,
  project_id uuid references public.projects(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.pricing_events enable row level security;

-- user can insert own events
drop policy if exists "pricing_events_insert_own" on public.pricing_events;
create policy "pricing_events_insert_own"
  on public.pricing_events
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- user can read own events
drop policy if exists "pricing_events_select_own" on public.pricing_events;
create policy "pricing_events_select_own"
  on public.pricing_events
  for select
  to authenticated
  using (auth.uid() = user_id);

-- service role may read all events
drop policy if exists "pricing_events_service_read" on public.pricing_events;
create policy "pricing_events_service_read"
  on public.pricing_events
  for select
  to service_role
  using (true);
