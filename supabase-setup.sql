-- Keegan's Card Stand: online storage for sync. Paste all of this into Supabase > SQL Editor > New query, then Run.

-- One table holds every record (cards, buys and sales, shows, prices, settings), one row per record.
create table if not exists public.records (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null,
  id text not null,
  data jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);
create index if not exists records_user_updated on public.records (user_id, updated_at);

-- Stamp every change with the server's time, so devices can ask "what changed since I last looked".
create or replace function public.records_touch() returns trigger language plpgsql as $$
begin new.updated_at = clock_timestamp(); return new; end $$;
drop trigger if exists records_touch on public.records;
create trigger records_touch before insert or update on public.records for each row execute function public.records_touch();

-- Lock it down: a signed-in account can only see and change its own rows. Nobody else can read anything.
alter table public.records enable row level security;
drop policy if exists "own records" on public.records;
create policy "own records" on public.records for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Private storage for card photos, one folder per account.
insert into storage.buckets (id, name, public) values ('card-photos', 'card-photos', false) on conflict (id) do nothing;
drop policy if exists "own photos read" on storage.objects;
drop policy if exists "own photos add" on storage.objects;
drop policy if exists "own photos change" on storage.objects;
create policy "own photos read" on storage.objects for select to authenticated
  using (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos add" on storage.objects for insert to authenticated
  with check (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos change" on storage.objects for update to authenticated
  using (bucket_id = 'card-photos' and (storage.foldername(name))[1] = auth.uid()::text);
