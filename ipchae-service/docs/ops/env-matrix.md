# Environment Matrix

## Public (client-side)
1. `PUBLIC_SUPABASE_URL`: Supabase project URL
2. `PUBLIC_SUPABASE_ANON_KEY`: Supabase anon key
3. `PUBLIC_APP_ENV`: `development|staging|production`
4. `PUBLIC_STARTER_CATALOG_VERSION`
5. `PUBLIC_PART_CATALOG_VERSION`
6. `PUBLIC_ACHIEVEMENT_CATALOG_VERSION`
7. `PUBLIC_COLLAB_MAX_EDITORS`

## Optional compatibility
1. `VITE_SUPABASE_URL`
2. `VITE_SUPABASE_ANON_KEY`

## Server-only
1. `SUPABASE_SERVICE_ROLE_KEY`
2. `SUPABASE_URL`
3. `APP_BASE_URL`
4. `GAMIFICATION_EVENT_SALT`
5. `COLLAB_LOCK_LEASE_SEC`
6. `COLLAB_LOCK_HEARTBEAT_SEC`

## Rules
1. Never expose service role key in client bundles.
2. Public keys can be used only with RLS enabled.

