# Pricing Event Contract v1

## Purpose
Capture paywall and upgrade funnel metrics for Free-first pricing experiments.

## Event Shape
```ts
type PricingTelemetryEvent = {
  eventID: string;
  eventType: 'paywall_viewed' | 'paywall_dismissed' | 'upgrade_clicked' | 'trial_started' | 'upgrade_completed';
  tier: 'free' | 'plus' | 'team';
  triggerEvent: 'createShareLink' | 'exportAdvancedFormat' | 'inviteCollaborator' | 'restoreOldVersion';
  reasonCode: string;
  projectID?: string;
  createdAtMs: number;
}
```

## Required Semantics
1. `eventID` must be globally unique for deduplication.
2. `reasonCode` should match product decision codes from pricing policy.
3. `triggerEvent` should represent the exact action that caused paywall display.

## Suggested Storage Mapping (Supabase)
Table name: `pricing_events`

Columns:
1. `id uuid primary key default gen_random_uuid()`
2. `event_id text not null unique`
3. `user_id uuid references auth.users(id) on delete set null`
4. `event_type text not null`
5. `tier text not null`
6. `trigger_event text not null`
7. `reason_code text not null`
8. `project_id uuid references public.projects(id) on delete set null`
9. `payload jsonb not null default '{}'::jsonb`
10. `created_at timestamptz not null default now()`

## Analytics Questions
1. Which trigger creates most upgrade clicks?
2. What is free->plus conversion by reason code?
3. Does paywall frequency hurt D1 retention?
