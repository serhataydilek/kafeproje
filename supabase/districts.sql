create table if not exists public.districts (
  id text primary key,
  city text not null,
  name text not null,
  display_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  search_radius_meters integer,
  northeast_lat double precision,
  northeast_lng double precision,
  southwest_lat double precision,
  southwest_lng double precision,
  aliases text[] not null default '{}',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists districts_city_sort_idx
  on public.districts (city, sort_order, display_name);

create index if not exists districts_active_city_idx
  on public.districts (is_active, city);

create or replace function public.set_districts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists districts_set_updated_at on public.districts;

create trigger districts_set_updated_at
before update on public.districts
for each row
execute function public.set_districts_updated_at();
