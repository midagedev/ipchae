-- IPCHAE (입채) Supabase Schema + RLS
-- Apply in Supabase SQL editor (order-sensitive)

-- 0) Extensions
create extension if not exists pgcrypto;

-- 1) Core project tables
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  thumbnail_path text,
  latest_version integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_versions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  version integer not null,
  scene_path text not null,
  scene_hash text,
  created_at timestamptz not null default now(),
  unique(project_id, version)
);

create table if not exists public.layers (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  visible boolean not null default true,
  color_hex text,
  created_at timestamptz not null default now(),
  unique(project_id, name)
);

create table if not exists public.exports (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  format text not null check (format in ('stl', 'ply')),
  storage_path text not null,
  file_size bigint,
  created_at timestamptz not null default now()
);

create table if not exists public.sync_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  event_type text not null,
  status text not null check (status in ('started', 'success', 'failed')),
  detail jsonb,
  created_at timestamptz not null default now()
);

-- 2) Starter catalog tables (official baseline)
create table if not exists public.starter_packs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  cover_image_path text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.starter_templates (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.starter_packs(id) on delete cascade,
  slug text not null,
  name text not null,
  description text,
  target_style text not null check (target_style in ('nendo', 'moe', 'minecraft', 'roblox', 'anime', 'animal', 'robot', 'fantasy', 'generic')),
  difficulty text not null default 'easy' check (difficulty in ('easy', 'normal', 'advanced')),
  default_scale double precision not null default 1.0,
  base_scene_path text not null,
  preview_image_path text,
  tags text[] not null default '{}'::text[],
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(pack_id, slug)
);

create table if not exists public.starter_template_parts (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.starter_templates(id) on delete cascade,
  part_key text not null,
  display_name text not null,
  part_kind text not null check (part_kind in ('core', 'face', 'hair', 'outfit', 'accessory', 'joint', 'voxel')),
  primitive_type text not null check (primitive_type in ('sphere', 'capsule', 'box', 'custom')),
  default_transform jsonb not null default '{}'::jsonb,
  editable_params jsonb not null default '{}'::jsonb,
  default_color_hex text,
  mirror_group text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(template_id, part_key)
);

create table if not exists public.project_starter_instances (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  template_id uuid references public.starter_templates(id) on delete set null,
  applied_params jsonb not null default '{}'::jsonb,
  applied_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete cascade
);

-- 3) Project share/remix tables
create table if not exists public.project_shares (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  share_slug text not null unique,
  title text not null,
  description text,
  visibility text not null default 'unlisted' check (visibility in ('public', 'unlisted', 'private')),
  allow_clone boolean not null default true,
  og_image_path text,
  source_version integer not null default 0,
  view_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_remixes (
  id uuid primary key default gen_random_uuid(),
  source_share_id uuid references public.project_shares(id) on delete set null,
  source_project_id uuid references public.projects(id) on delete set null,
  remix_project_id uuid not null references public.projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(remix_project_id)
);

create table if not exists public.share_events (
  id uuid primary key default gen_random_uuid(),
  share_id uuid not null references public.project_shares(id) on delete cascade,
  event_type text not null check (event_type in ('share_view', 'share_cta_click', 'share_clone_success', 'share_repost')),
  viewer_id uuid references auth.users(id) on delete set null,
  referrer text,
  user_agent text,
  created_at timestamptz not null default now()
);

-- 4) Part library + part sharing tables
create table if not exists public.part_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  parent_id uuid references public.part_categories(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  slug text not null unique,
  name text not null,
  description text,
  source_type text not null default 'user' check (source_type in ('official', 'user')),
  visibility text not null default 'private' check (visibility in ('private', 'unlisted', 'public')),
  category_id uuid references public.part_categories(id) on delete set null,
  style_family text not null default 'generic' check (style_family in ('nendo', 'moe', 'minecraft', 'roblox', 'anime', 'animal', 'robot', 'fantasy', 'generic')),
  mesh_path text not null,
  preview_image_path text,
  tags text[] not null default '{}'::text[],
  poly_count integer,
  allow_remix boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.part_shares (
  id uuid primary key default gen_random_uuid(),
  part_id uuid not null references public.parts(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete set null,
  share_slug text not null unique,
  title text not null,
  description text,
  visibility text not null default 'unlisted' check (visibility in ('public', 'unlisted', 'private')),
  allow_import boolean not null default true,
  allow_remix boolean not null default true,
  og_image_path text,
  view_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.part_remixes (
  id uuid primary key default gen_random_uuid(),
  source_part_share_id uuid references public.part_shares(id) on delete set null,
  source_part_id uuid references public.parts(id) on delete set null,
  remix_part_id uuid not null references public.parts(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(remix_part_id)
);

create table if not exists public.part_events (
  id uuid primary key default gen_random_uuid(),
  part_share_id uuid not null references public.part_shares(id) on delete cascade,
  event_type text not null check (event_type in ('part_share_view', 'part_import_success', 'part_remix_success', 'part_like')),
  viewer_id uuid references auth.users(id) on delete set null,
  referrer text,
  user_agent text,
  created_at timestamptz not null default now()
);

create table if not exists public.project_used_parts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  part_id uuid references public.parts(id) on delete set null,
  source_part_share_id uuid references public.part_shares(id) on delete set null,
  inserted_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 4.5) Gamification tables
create table if not exists public.gamification_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  level integer not null default 1 check (level >= 1),
  total_xp bigint not null default 0 check (total_xp >= 0),
  current_level_xp integer not null default 0 check (current_level_xp >= 0),
  next_level_xp integer not null default 100 check (next_level_xp > 0),
  streak_days integer not null default 0 check (streak_days >= 0),
  last_active_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.achievement_catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  category text not null check (category in ('tool', 'project', 'part', 'share', 'community', 'export', 'starter', 'streak')),
  metric_key text not null,
  threshold_value integer not null check (threshold_value > 0),
  xp_reward integer not null default 0 check (xp_reward >= 0),
  rarity text not null default 'common' check (rarity in ('common', 'rare', 'epic', 'legendary')),
  is_repeatable boolean not null default false,
  cooldown_hours integer not null default 0 check (cooldown_hours >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_achievement_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references public.achievement_catalog(id) on delete cascade,
  progress_value bigint not null default 0 check (progress_value >= 0),
  is_unlocked boolean not null default false,
  unlocked_at timestamptz,
  unlock_count integer not null default 0 check (unlock_count >= 0),
  last_progress_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, achievement_id)
);

create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null check (source_type in (
    'tool_first_use',
    'tool_usage_milestone',
    'project_share_created',
    'part_share_created',
    'project_clone_received',
    'part_import_received',
    'part_remix_received',
    'achievement_unlock',
    'export_success',
    'daily_streak_bonus',
    'manual_adjustment'
  )),
  source_ref text,
  xp_delta integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.tool_usage_stats (
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_id text not null,
  total_count bigint not null default 0 check (total_count >= 0),
  first_used_at timestamptz,
  last_used_at timestamptz,
  last_project_id uuid references public.projects(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(user_id, tool_id)
);

create table if not exists public.gamification_event_dedup (
  event_key text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  source_table text,
  source_id uuid,
  created_at timestamptz not null default now()
);

-- 4.6) Real-time collaboration tables
create table if not exists public.project_collaborators (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'editor' check (role in ('owner', 'editor', 'viewer')),
  status text not null default 'invited' check (status in ('invited', 'active', 'revoked')),
  invited_by uuid references auth.users(id) on delete set null,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, user_id)
);

create table if not exists public.project_collab_invites (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique,
  default_role text not null default 'editor' check (default_role in ('editor', 'viewer')),
  max_editors integer check (max_editors is null or (max_editors >= 1 and max_editors <= 8)),
  expires_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_collab_sessions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  host_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'ended')),
  max_editors integer not null default 4 check (max_editors >= 1 and max_editors <= 8),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_presence (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.project_collab_sessions(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  cursor_world jsonb not null default '{}'::jsonb,
  camera_state jsonb not null default '{}'::jsonb,
  selected_mesh_node_id text,
  heartbeat_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(session_id, user_id)
);

create table if not exists public.project_mesh_locks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  session_id uuid references public.project_collab_sessions(id) on delete set null,
  mesh_node_id text not null,
  lock_scope text not null default 'node' check (lock_scope in ('node', 'submesh')),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  lease_expires_at timestamptz not null,
  is_active boolean not null default true,
  released_at timestamptz,
  release_reason text check (release_reason in ('manual', 'expired', 'forced', 'disconnect')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_ops (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  session_id uuid references public.project_collab_sessions(id) on delete set null,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  base_version integer not null check (base_version >= 0),
  op_seq bigint not null check (op_seq >= 0),
  mesh_node_id text,
  op_type text not null check (op_type in ('draw', 'blob_add', 'push_pull', 'smooth', 'carve', 'color', 'transform', 'delete', 'import', 'layer')),
  op_payload jsonb not null default '{}'::jsonb,
  status text not null default 'accepted' check (status in ('accepted', 'rejected', 'conflict')),
  applied_version integer,
  created_at timestamptz not null default now(),
  unique(session_id, actor_user_id, op_seq)
);

create table if not exists public.project_collab_conflicts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  session_id uuid references public.project_collab_sessions(id) on delete set null,
  op_id uuid references public.project_ops(id) on delete set null,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  conflict_type text not null check (conflict_type in ('stale_base', 'lock_missing', 'lock_held', 'invalid_op')),
  detail jsonb not null default '{}'::jsonb,
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5) Indexes
create index if not exists idx_projects_owner_updated on public.projects(owner_id, updated_at desc);
create index if not exists idx_versions_project_version on public.project_versions(project_id, version desc);
create index if not exists idx_layers_project_order on public.layers(project_id, sort_order asc);
create index if not exists idx_exports_project_created on public.exports(project_id, created_at desc);
create index if not exists idx_sync_events_project_created on public.sync_events(project_id, created_at desc);

create index if not exists idx_starter_packs_active_sort on public.starter_packs(is_active, sort_order asc);
create index if not exists idx_starter_templates_pack_sort on public.starter_templates(pack_id, sort_order asc);
create index if not exists idx_starter_templates_style on public.starter_templates(target_style, difficulty, sort_order asc);
create index if not exists idx_starter_parts_template_sort on public.starter_template_parts(template_id, sort_order asc);
create index if not exists idx_project_starter_instances_project on public.project_starter_instances(project_id, applied_at desc);

create index if not exists idx_project_shares_project on public.project_shares(project_id, created_at desc);
create index if not exists idx_project_shares_slug on public.project_shares(share_slug);
create index if not exists idx_project_shares_visibility on public.project_shares(visibility, created_at desc);
create index if not exists idx_project_remixes_source_share on public.project_remixes(source_share_id, created_at desc);
create index if not exists idx_share_events_share_created on public.share_events(share_id, created_at desc);

create index if not exists idx_part_categories_parent_sort on public.part_categories(parent_id, sort_order asc);
create index if not exists idx_parts_owner_updated on public.parts(owner_id, updated_at desc);
create index if not exists idx_parts_visibility_updated on public.parts(visibility, updated_at desc);
create index if not exists idx_parts_category_style on public.parts(category_id, style_family, updated_at desc);
create index if not exists idx_parts_slug on public.parts(slug);
create index if not exists idx_parts_tags_gin on public.parts using gin(tags);
create index if not exists idx_part_shares_part_created on public.part_shares(part_id, created_at desc);
create index if not exists idx_part_shares_slug on public.part_shares(share_slug);
create index if not exists idx_part_remixes_source_share on public.part_remixes(source_part_share_id, created_at desc);
create index if not exists idx_part_events_share_created on public.part_events(part_share_id, created_at desc);
create index if not exists idx_project_used_parts_project on public.project_used_parts(project_id, created_at desc);
create index if not exists idx_gamification_profiles_level on public.gamification_profiles(level desc, total_xp desc);
create index if not exists idx_achievement_catalog_active_sort on public.achievement_catalog(is_active, sort_order asc);
create index if not exists idx_achievement_catalog_metric on public.achievement_catalog(metric_key, threshold_value asc);
create index if not exists idx_user_achievement_progress_user on public.user_achievement_progress(user_id, updated_at desc);
create index if not exists idx_user_achievement_progress_unlocked on public.user_achievement_progress(user_id, is_unlocked, unlocked_at desc);
create index if not exists idx_xp_events_user_created on public.xp_events(user_id, created_at desc);
create index if not exists idx_xp_events_source on public.xp_events(source_type, created_at desc);
create index if not exists idx_tool_usage_stats_user_last on public.tool_usage_stats(user_id, last_used_at desc);
create index if not exists idx_gamification_event_dedup_user on public.gamification_event_dedup(user_id, created_at desc);
create index if not exists idx_project_collaborators_project_status on public.project_collaborators(project_id, status, role);
create index if not exists idx_project_collaborators_user_status on public.project_collaborators(user_id, status);
create index if not exists idx_project_collab_invites_code_active on public.project_collab_invites(invite_code, is_active, expires_at);
create index if not exists idx_project_collab_invites_project_active on public.project_collab_invites(project_id, is_active, created_at desc);
create index if not exists idx_project_collab_sessions_project_status on public.project_collab_sessions(project_id, status, started_at desc);
create index if not exists idx_project_presence_session_heartbeat on public.project_presence(session_id, heartbeat_at desc);
create index if not exists idx_project_mesh_locks_project_active on public.project_mesh_locks(project_id, is_active, lease_expires_at);
create unique index if not exists idx_project_mesh_locks_active_unique
  on public.project_mesh_locks(project_id, mesh_node_id)
  where is_active = true;
create index if not exists idx_project_ops_project_created on public.project_ops(project_id, created_at desc);
create index if not exists idx_project_ops_session_seq on public.project_ops(session_id, op_seq asc);
create index if not exists idx_project_collab_conflicts_session_created on public.project_collab_conflicts(session_id, created_at desc);

-- 6) updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_projects_updated_at on public.projects;
create trigger trg_projects_updated_at
before update on public.projects
for each row
execute function public.set_updated_at();

drop trigger if exists trg_starter_packs_updated_at on public.starter_packs;
create trigger trg_starter_packs_updated_at
before update on public.starter_packs
for each row
execute function public.set_updated_at();

drop trigger if exists trg_starter_templates_updated_at on public.starter_templates;
create trigger trg_starter_templates_updated_at
before update on public.starter_templates
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_shares_updated_at on public.project_shares;
create trigger trg_project_shares_updated_at
before update on public.project_shares
for each row
execute function public.set_updated_at();

drop trigger if exists trg_part_categories_updated_at on public.part_categories;
create trigger trg_part_categories_updated_at
before update on public.part_categories
for each row
execute function public.set_updated_at();

drop trigger if exists trg_parts_updated_at on public.parts;
create trigger trg_parts_updated_at
before update on public.parts
for each row
execute function public.set_updated_at();

drop trigger if exists trg_part_shares_updated_at on public.part_shares;
create trigger trg_part_shares_updated_at
before update on public.part_shares
for each row
execute function public.set_updated_at();

drop trigger if exists trg_gamification_profiles_updated_at on public.gamification_profiles;
create trigger trg_gamification_profiles_updated_at
before update on public.gamification_profiles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_achievement_catalog_updated_at on public.achievement_catalog;
create trigger trg_achievement_catalog_updated_at
before update on public.achievement_catalog
for each row
execute function public.set_updated_at();

drop trigger if exists trg_user_achievement_progress_updated_at on public.user_achievement_progress;
create trigger trg_user_achievement_progress_updated_at
before update on public.user_achievement_progress
for each row
execute function public.set_updated_at();

drop trigger if exists trg_tool_usage_stats_updated_at on public.tool_usage_stats;
create trigger trg_tool_usage_stats_updated_at
before update on public.tool_usage_stats
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_collaborators_updated_at on public.project_collaborators;
create trigger trg_project_collaborators_updated_at
before update on public.project_collaborators
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_collab_invites_updated_at on public.project_collab_invites;
create trigger trg_project_collab_invites_updated_at
before update on public.project_collab_invites
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_collab_sessions_updated_at on public.project_collab_sessions;
create trigger trg_project_collab_sessions_updated_at
before update on public.project_collab_sessions
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_presence_updated_at on public.project_presence;
create trigger trg_project_presence_updated_at
before update on public.project_presence
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_mesh_locks_updated_at on public.project_mesh_locks;
create trigger trg_project_mesh_locks_updated_at
before update on public.project_mesh_locks
for each row
execute function public.set_updated_at();

drop trigger if exists trg_project_collab_conflicts_updated_at on public.project_collab_conflicts;
create trigger trg_project_collab_conflicts_updated_at
before update on public.project_collab_conflicts
for each row
execute function public.set_updated_at();

-- 7) Helper predicates
create or replace function public.is_project_owner(pid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = pid
      and p.owner_id = auth.uid()
  );
$$;

create or replace function public.is_project_member(pid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = pid
      and p.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.project_collaborators c
    where c.project_id = pid
      and c.user_id = auth.uid()
      and c.status = 'active'
  );
$$;

create or replace function public.is_project_editor(pid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = pid
      and p.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.project_collaborators c
    where c.project_id = pid
      and c.user_id = auth.uid()
      and c.status = 'active'
      and c.role = 'editor'
  );
$$;

create or replace function public.can_access_collab_session(sid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_collab_sessions s
    where s.id = sid
      and s.status = 'active'
      and public.is_project_member(s.project_id)
  );
$$;

create or replace function public.is_part_owner(pid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.parts p
    where p.id = pid
      and p.owner_id = auth.uid()
  );
$$;

create or replace function public.can_read_share(sid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_shares s
    where s.id = sid
      and (
        s.visibility in ('public', 'unlisted')
        or s.owner_id = auth.uid()
      )
  );
$$;

create or replace function public.can_read_part_share(sid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.part_shares s
    join public.parts p
      on p.id = s.part_id
    where s.id = sid
      and p.is_active = true
      and (
        s.visibility in ('public', 'unlisted')
        or s.owner_id = auth.uid()
      )
  );
$$;

-- 8) RLS enable
alter table public.projects enable row level security;
alter table public.project_versions enable row level security;
alter table public.layers enable row level security;
alter table public.exports enable row level security;
alter table public.sync_events enable row level security;
alter table public.starter_packs enable row level security;
alter table public.starter_templates enable row level security;
alter table public.starter_template_parts enable row level security;
alter table public.project_starter_instances enable row level security;
alter table public.project_shares enable row level security;
alter table public.project_remixes enable row level security;
alter table public.share_events enable row level security;
alter table public.part_categories enable row level security;
alter table public.parts enable row level security;
alter table public.part_shares enable row level security;
alter table public.part_remixes enable row level security;
alter table public.part_events enable row level security;
alter table public.project_used_parts enable row level security;
alter table public.gamification_profiles enable row level security;
alter table public.achievement_catalog enable row level security;
alter table public.user_achievement_progress enable row level security;
alter table public.xp_events enable row level security;
alter table public.tool_usage_stats enable row level security;
alter table public.gamification_event_dedup enable row level security;
alter table public.project_collaborators enable row level security;
alter table public.project_collab_invites enable row level security;
alter table public.project_collab_sessions enable row level security;
alter table public.project_presence enable row level security;
alter table public.project_mesh_locks enable row level security;
alter table public.project_ops enable row level security;
alter table public.project_collab_conflicts enable row level security;

-- 9) RLS policies: projects
create policy "projects_select_own"
on public.projects for select
to authenticated
using (public.is_project_member(id));

create policy "projects_insert_own"
on public.projects for insert
to authenticated
with check (owner_id = auth.uid());

create policy "projects_update_own"
on public.projects for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "projects_delete_own"
on public.projects for delete
to authenticated
using (owner_id = auth.uid());

-- 10) RLS policies: project_versions
create policy "versions_select_owner"
on public.project_versions for select
to authenticated
using (public.is_project_member(project_id));

create policy "versions_insert_owner"
on public.project_versions for insert
to authenticated
with check (public.is_project_editor(project_id));

create policy "versions_update_owner"
on public.project_versions for update
to authenticated
using (public.is_project_editor(project_id))
with check (public.is_project_editor(project_id));

create policy "versions_delete_owner"
on public.project_versions for delete
to authenticated
using (public.is_project_editor(project_id));

-- 11) RLS policies: layers
create policy "layers_select_owner"
on public.layers for select
to authenticated
using (public.is_project_member(project_id));

create policy "layers_insert_owner"
on public.layers for insert
to authenticated
with check (public.is_project_editor(project_id));

create policy "layers_update_owner"
on public.layers for update
to authenticated
using (public.is_project_editor(project_id))
with check (public.is_project_editor(project_id));

create policy "layers_delete_owner"
on public.layers for delete
to authenticated
using (public.is_project_editor(project_id));

-- 12) RLS policies: exports
create policy "exports_select_owner"
on public.exports for select
to authenticated
using (public.is_project_member(project_id));

create policy "exports_insert_owner"
on public.exports for insert
to authenticated
with check (public.is_project_editor(project_id));

create policy "exports_delete_owner"
on public.exports for delete
to authenticated
using (public.is_project_editor(project_id));

-- 13) RLS policies: sync_events
create policy "sync_events_select_owner"
on public.sync_events for select
to authenticated
using (public.is_project_member(project_id));

create policy "sync_events_insert_owner"
on public.sync_events for insert
to authenticated
with check (public.is_project_editor(project_id));

-- 14) RLS policies: starter catalog (read public)
create policy "starter_packs_select_public"
on public.starter_packs for select
to anon, authenticated
using (is_active = true);

create policy "starter_templates_select_public"
on public.starter_templates for select
to anon, authenticated
using (
  is_active = true
  and exists (
    select 1
    from public.starter_packs sp
    where sp.id = pack_id
      and sp.is_active = true
  )
);

create policy "starter_parts_select_public"
on public.starter_template_parts for select
to anon, authenticated
using (
  exists (
    select 1
    from public.starter_templates st
    join public.starter_packs sp
      on sp.id = st.pack_id
    where st.id = template_id
      and st.is_active = true
      and sp.is_active = true
  )
);

-- NOTE: starter catalog writes are intentionally omitted from RLS policies.
-- Admin/service_role should write starter data.

-- 15) RLS policies: project_starter_instances
create policy "starter_instances_select_owner"
on public.project_starter_instances for select
to authenticated
using (public.is_project_member(project_id));

create policy "starter_instances_insert_owner"
on public.project_starter_instances for insert
to authenticated
with check (
  public.is_project_editor(project_id)
  and created_by = auth.uid()
);

create policy "starter_instances_update_owner"
on public.project_starter_instances for update
to authenticated
using (public.is_project_editor(project_id))
with check (public.is_project_editor(project_id));

create policy "starter_instances_delete_owner"
on public.project_starter_instances for delete
to authenticated
using (public.is_project_editor(project_id));

-- 16) RLS policies: project shares/remixes/events
create policy "shares_select_visible"
on public.project_shares for select
to anon, authenticated
using (
  visibility in ('public', 'unlisted')
  or owner_id = auth.uid()
);

create policy "shares_insert_owner"
on public.project_shares for insert
to authenticated
with check (
  owner_id = auth.uid()
  and public.is_project_owner(project_id)
);

create policy "shares_update_owner"
on public.project_shares for update
to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and public.is_project_owner(project_id)
);

create policy "shares_delete_owner"
on public.project_shares for delete
to authenticated
using (owner_id = auth.uid());

create policy "remixes_select_owner"
on public.project_remixes for select
to authenticated
using (owner_id = auth.uid());

create policy "remixes_insert_owner"
on public.project_remixes for insert
to authenticated
with check (
  owner_id = auth.uid()
  and public.is_project_owner(remix_project_id)
);

create policy "share_events_select_owner"
on public.share_events for select
to authenticated
using (
  exists (
    select 1
    from public.project_shares s
    where s.id = share_id
      and s.owner_id = auth.uid()
  )
);

create policy "share_events_insert_visible_share"
on public.share_events for insert
to anon, authenticated
with check (public.can_read_share(share_id));

-- 17) RLS policies: part categories
create policy "part_categories_select_public"
on public.part_categories for select
to anon, authenticated
using (is_active = true);

-- NOTE: part_categories writes are intentionally omitted from RLS policies.
-- Admin/service_role should write category data.

-- 18) RLS policies: parts
create policy "parts_select_visible"
on public.parts for select
to anon, authenticated
using (
  is_active = true
  and (
    visibility in ('public', 'unlisted')
    or owner_id = auth.uid()
  )
);

create policy "parts_insert_owner"
on public.parts for insert
to authenticated
with check (
  owner_id = auth.uid()
  and source_type = 'user'
);

create policy "parts_update_owner"
on public.parts for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "parts_delete_owner"
on public.parts for delete
to authenticated
using (owner_id = auth.uid());

-- 19) RLS policies: part shares/remixes/events
create policy "part_shares_select_visible"
on public.part_shares for select
to anon, authenticated
using (
  (
    visibility in ('public', 'unlisted')
    and exists (
      select 1
      from public.parts p
      where p.id = part_id
        and p.is_active = true
    )
  )
  or owner_id = auth.uid()
);

create policy "part_shares_insert_owner"
on public.part_shares for insert
to authenticated
with check (
  owner_id = auth.uid()
  and public.is_part_owner(part_id)
);

create policy "part_shares_update_owner"
on public.part_shares for update
to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and public.is_part_owner(part_id)
);

create policy "part_shares_delete_owner"
on public.part_shares for delete
to authenticated
using (owner_id = auth.uid());

create policy "part_remixes_select_owner"
on public.part_remixes for select
to authenticated
using (owner_id = auth.uid());

create policy "part_remixes_insert_owner"
on public.part_remixes for insert
to authenticated
with check (
  owner_id = auth.uid()
  and public.is_part_owner(remix_part_id)
);

create policy "part_events_select_owner"
on public.part_events for select
to authenticated
using (
  exists (
    select 1
    from public.part_shares s
    where s.id = part_share_id
      and s.owner_id = auth.uid()
  )
);

create policy "part_events_insert_visible_share"
on public.part_events for insert
to anon, authenticated
with check (public.can_read_part_share(part_share_id));

-- 20) RLS policies: project used parts mapping
create policy "project_used_parts_select_owner"
on public.project_used_parts for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_used_parts_insert_owner"
on public.project_used_parts for insert
to authenticated
with check (
  public.is_project_editor(project_id)
  and inserted_by = auth.uid()
);

create policy "project_used_parts_delete_owner"
on public.project_used_parts for delete
to authenticated
using (public.is_project_editor(project_id));

-- 20.1) RLS policies: gamification
create policy "achievement_catalog_select_public"
on public.achievement_catalog for select
to anon, authenticated
using (is_active = true);

create policy "gamification_profiles_select_own"
on public.gamification_profiles for select
to authenticated
using (user_id = auth.uid());

create policy "gamification_profiles_insert_own_default"
on public.gamification_profiles for insert
to authenticated
with check (
  user_id = auth.uid()
  and level = 1
  and total_xp = 0
  and current_level_xp = 0
  and next_level_xp = 100
  and streak_days = 0
);

create policy "achievement_progress_select_own"
on public.user_achievement_progress for select
to authenticated
using (user_id = auth.uid());

create policy "xp_events_select_own"
on public.xp_events for select
to authenticated
using (user_id = auth.uid());

create policy "tool_usage_stats_select_own"
on public.tool_usage_stats for select
to authenticated
using (user_id = auth.uid());

create policy "gamification_event_dedup_select_own"
on public.gamification_event_dedup for select
to authenticated
using (user_id = auth.uid());

-- NOTE: gamification writes(achievement progress, xp events, tool usage upsert)는
-- Edge Functions/service_role 경로를 기본으로 사용한다.

-- 20.2) RLS policies: collaboration
create policy "project_collaborators_select_member"
on public.project_collaborators for select
to authenticated
using (
  public.is_project_owner(project_id)
  or public.is_project_member(project_id)
  or user_id = auth.uid()
);

create policy "project_collaborators_insert_owner"
on public.project_collaborators for insert
to authenticated
with check (
  public.is_project_owner(project_id)
  and invited_by = auth.uid()
);

create policy "project_collaborators_update_owner"
on public.project_collaborators for update
to authenticated
using (public.is_project_owner(project_id))
with check (public.is_project_owner(project_id));

create policy "project_collaborators_update_self"
on public.project_collaborators for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and status in ('active', 'revoked')
);

create policy "project_collaborators_delete_owner_or_self"
on public.project_collaborators for delete
to authenticated
using (
  public.is_project_owner(project_id)
  or user_id = auth.uid()
);

create policy "project_collab_invites_select_member"
on public.project_collab_invites for select
to authenticated
using (
  public.is_project_owner(project_id)
  or public.is_project_member(project_id)
);

create policy "project_collab_invites_insert_owner"
on public.project_collab_invites for insert
to authenticated
with check (
  public.is_project_owner(project_id)
  and created_by = auth.uid()
);

create policy "project_collab_invites_update_owner"
on public.project_collab_invites for update
to authenticated
using (public.is_project_owner(project_id))
with check (public.is_project_owner(project_id));

create policy "project_collab_invites_delete_owner"
on public.project_collab_invites for delete
to authenticated
using (public.is_project_owner(project_id));

create policy "project_collab_sessions_select_member"
on public.project_collab_sessions for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_collab_sessions_insert_editor"
on public.project_collab_sessions for insert
to authenticated
with check (
  public.is_project_editor(project_id)
  and host_user_id = auth.uid()
);

create policy "project_collab_sessions_update_host_or_owner"
on public.project_collab_sessions for update
to authenticated
using (
  host_user_id = auth.uid()
  or public.is_project_owner(project_id)
)
with check (
  host_user_id = auth.uid()
  or public.is_project_owner(project_id)
);

create policy "project_collab_sessions_delete_host_or_owner"
on public.project_collab_sessions for delete
to authenticated
using (
  host_user_id = auth.uid()
  or public.is_project_owner(project_id)
);

create policy "project_presence_select_member"
on public.project_presence for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_presence_insert_self"
on public.project_presence for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.can_access_collab_session(session_id)
  and exists (
    select 1
    from public.project_collab_sessions s
    where s.id = session_id
      and s.project_id = project_id
  )
);

create policy "project_presence_update_self"
on public.project_presence for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.can_access_collab_session(session_id)
);

create policy "project_presence_delete_self_or_owner"
on public.project_presence for delete
to authenticated
using (
  user_id = auth.uid()
  or public.is_project_owner(project_id)
);

create policy "project_mesh_locks_select_member"
on public.project_mesh_locks for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_mesh_locks_insert_editor"
on public.project_mesh_locks for insert
to authenticated
with check (
  owner_user_id = auth.uid()
  and public.is_project_editor(project_id)
  and is_active = true
);

create policy "project_mesh_locks_update_owner_or_project_owner"
on public.project_mesh_locks for update
to authenticated
using (
  owner_user_id = auth.uid()
  or public.is_project_owner(project_id)
)
with check (
  (owner_user_id = auth.uid() and public.is_project_editor(project_id))
  or public.is_project_owner(project_id)
);

create policy "project_mesh_locks_delete_owner_or_project_owner"
on public.project_mesh_locks for delete
to authenticated
using (
  owner_user_id = auth.uid()
  or public.is_project_owner(project_id)
);

create policy "project_ops_select_member"
on public.project_ops for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_ops_insert_editor"
on public.project_ops for insert
to authenticated
with check (
  actor_user_id = auth.uid()
  and public.is_project_editor(project_id)
);

create policy "project_collab_conflicts_select_member"
on public.project_collab_conflicts for select
to authenticated
using (public.is_project_member(project_id));

create policy "project_collab_conflicts_insert_editor"
on public.project_collab_conflicts for insert
to authenticated
with check (
  actor_user_id = auth.uid()
  and public.is_project_editor(project_id)
);

create policy "project_collab_conflicts_update_editor_or_owner"
on public.project_collab_conflicts for update
to authenticated
using (
  public.is_project_editor(project_id)
  or public.is_project_owner(project_id)
)
with check (
  public.is_project_editor(project_id)
  or public.is_project_owner(project_id)
);

-- 21) Storage buckets
insert into storage.buckets (id, name, public)
values ('scene', 'scene', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('exports', 'exports', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('thumbs', 'thumbs', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('starter-assets', 'starter-assets', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('share-og', 'share-og', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('part-files', 'part-files', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('part-preview', 'part-preview', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('part-og', 'part-og', true)
on conflict (id) do nothing;

-- 22) Storage policies
-- path convention:
-- scene:          {uid}/{project_id}/{version}.json
-- exports:        {uid}/{project_id}/{filename}.stl|ply
-- thumbs:         {uid}/{project_id}/thumb.png
-- starter-assets: packs/{pack_slug}/{template_slug}/preview.png|scene.json|parts/*.json
-- share-og:       {uid}/{share_id}/og.png
-- part-files:     private/{uid}/{part_id}/mesh.glb|ply|obj OR public/{part_id}/mesh.glb|ply|obj
-- part-preview:   {uid}/{part_id}/thumb.png
-- part-og:        {uid}/{part_share_id}/og.png

create policy "scene_read_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'scene'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "scene_write_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'scene'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "scene_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'scene'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'scene'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "scene_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'scene'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "exports_read_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'exports'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "exports_write_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'exports'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "exports_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'exports'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "thumbs_read_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'thumbs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "thumbs_write_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'thumbs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "thumbs_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'thumbs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "starter_assets_read_public"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'starter-assets');

create policy "share_og_read_public"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'share-og');

create policy "share_og_write_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'share-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.project_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

create policy "share_og_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'share-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.project_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
)
with check (
  bucket_id = 'share-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.project_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

create policy "share_og_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'share-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.project_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

create policy "part_files_read_public"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'public'
);

create policy "part_files_read_private_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'private'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "part_files_write_private_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'private'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "part_files_update_private_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'private'
  and (storage.foldername(name))[2] = auth.uid()::text
)
with check (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'private'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "part_files_delete_private_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'private'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "part_files_write_public_owner"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'public'
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
      and p.visibility in ('public', 'unlisted')
  )
);

create policy "part_files_update_public_owner"
on storage.objects for update
to authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'public'
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
      and p.visibility in ('public', 'unlisted')
  )
)
with check (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'public'
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
      and p.visibility in ('public', 'unlisted')
  )
);

create policy "part_files_delete_public_owner"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'part-files'
  and (storage.foldername(name))[1] = 'public'
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
  )
);

create policy "part_preview_read_public"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'part-preview');

create policy "part_preview_write_owner"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'part-preview'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
  )
);

create policy "part_preview_update_owner"
on storage.objects for update
to authenticated
using (
  bucket_id = 'part-preview'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
  )
)
with check (
  bucket_id = 'part-preview'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
  )
);

create policy "part_preview_delete_owner"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'part-preview'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.parts p
    where p.id::text = (storage.foldername(name))[2]
      and p.owner_id = auth.uid()
  )
);

create policy "part_og_read_public"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'part-og');

create policy "part_og_write_owner"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'part-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.part_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

create policy "part_og_update_owner"
on storage.objects for update
to authenticated
using (
  bucket_id = 'part-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.part_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
)
with check (
  bucket_id = 'part-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.part_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

create policy "part_og_delete_owner"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'part-og'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.part_shares s
    where s.id::text = (storage.foldername(name))[2]
      and s.owner_id = auth.uid()
  )
);

-- 23) Optional seed query helpers
-- select * from public.projects order by updated_at desc;
-- select * from public.project_versions where project_id = '...';
-- select * from public.starter_packs where is_active = true order by sort_order;
-- select * from public.starter_templates where is_active = true order by sort_order;
-- select * from public.project_shares where visibility in ('public','unlisted') order by created_at desc;
-- select * from public.parts where visibility = 'public' and is_active = true order by updated_at desc;
-- select * from public.part_shares where visibility in ('public','unlisted') order by created_at desc;
-- select * from public.gamification_profiles where user_id = auth.uid();
-- select * from public.user_achievement_progress where user_id = auth.uid() order by updated_at desc;
-- select * from public.xp_events where user_id = auth.uid() order by created_at desc limit 100;
-- select * from public.project_collaborators where project_id = '...';
-- select * from public.project_collab_sessions where project_id = '...' order by started_at desc;
-- select * from public.project_mesh_locks where project_id = '...' and is_active = true;
-- select * from public.project_ops where project_id = '...' order by created_at desc limit 200;
