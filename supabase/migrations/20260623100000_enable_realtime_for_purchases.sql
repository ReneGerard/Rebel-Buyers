-- public.purchases, its RLS, and its policies already exist (applied manually,
-- like the original wishlists/items schema). The only missing piece for the
-- public share page's live-update requirement is Realtime broadcast.
alter publication supabase_realtime add table public.purchases;
