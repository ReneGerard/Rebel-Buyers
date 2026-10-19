# Repairing the production migration history after the baseline

Status: **written, not executed. Waits for the project owner's approval, in a separate session.**

Why: `supabase/migrations/20260708110000_live_baseline.sql` replaces the four earlier files. The live
`supabase_migrations.schema_migrations` table still lists those four versions and not the baseline. Without a repair,
`supabase db push` would try to run the baseline on a database that already has every object.
Repairing writes to production's migration table, so it follows the sprint 1 approval rule
(docs/sprint-1.md, "Rules for every database change").

Live history today (read-only `list_migrations`, 2026-10-19):
`20260622140000`, `20260623090000`, `20260623100000`, `20260708100000`.

## Preconditions

1. The owner dumped `wishlists`, `items` and `purchases` to a local file.
2. The baseline was rebuilt on a local Supabase (`supabase db reset`) and its catalog output matches live
   (CI does this once task 2 lands).
3. The owner approved this repair explicitly.

## Steps (Supabase CLI, run by the owner or in an approved session)

```bash
supabase link --project-ref ookqbhipqnocwfkbaneo

# 1. Mark the four replaced versions as reverted (removes their rows from the history table).
supabase migration repair --status reverted 20260622140000 20260623090000 20260623100000 20260708100000

# 2. Mark the baseline as applied (inserts its row; the SQL is NOT executed).
supabase migration repair --status applied 20260708110000

# 3. Check: local and remote must list exactly one version, 20260708110000.
supabase migration list
```

Equivalent SQL, only if the CLI cannot be used (this is DML on production, same approval needed):

```sql
delete from supabase_migrations.schema_migrations
 where version in ('20260622140000','20260623090000','20260623100000','20260708100000');
insert into supabase_migrations.schema_migrations (version, name)
 values ('20260708110000', 'live_baseline');
```

## Notes

- Neither step touches `public` objects or data.
- Rollback: `supabase migration repair --status reverted 20260708110000`, then `--status applied` on the four old
  versions (their files remain in git history before this change).
- Alternative considered: reuse version `20260622140000` for the baseline and revert only the other three.
  Rejected: the same version number would then name different SQL before and after.
