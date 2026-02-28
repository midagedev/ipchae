# API Error Codes v1

## Collaboration
1. `LOCK_HELD_BY_OTHER`: requested mesh lock is owned by another editor.
2. `LOCK_NOT_FOUND`: renew/release target lock does not exist.
3. `LOCK_EXPIRED`: lock lease already expired.
4. `CONFLICT_STALE_BASE`: submitted operation is based on outdated version.
5. `ROLE_FORBIDDEN`: role does not allow requested write action.

## Share/Part
1. `VISIBILITY_FORBIDDEN`: resource visibility does not allow access.
2. `CLONE_DISABLED`: clone is disabled for this share.
3. `IMPORT_DISABLED`: import/remix is disabled for this part share.

## Gamification
1. `XP_EVENT_DUPLICATED`: eventKey already consumed.
2. `XP_EVENT_SELF_ACTION`: viewer is owner; reward blocked.

