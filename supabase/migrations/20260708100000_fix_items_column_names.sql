-- Corrective migration: align remote column names with what migration files and
-- app code expect. The first migration was applied manually before these columns
-- were renamed, so the remote drifted: `url` should be `merchant_url` and
-- `notes` should be `note`.
alter table public.items rename column url to merchant_url;
alter table public.items rename column notes to note;
