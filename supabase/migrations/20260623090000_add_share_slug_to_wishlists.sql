alter table public.wishlists
  add column share_slug text not null default substr(md5(random()::text || clock_timestamp()::text), 1, 10);

alter table public.wishlists
  add constraint wishlists_share_slug_key unique (share_slug);
