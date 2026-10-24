-- =====================================================================
-- DailyWell — Supabase / PostgreSQL setup
-- Run this whole file once in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- It is safe to run again (idempotent): tables use IF NOT EXISTS, policies/triggers are re-created.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Helper functions
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Prevents a row from ever being handed to a different account.
create or replace function public.prevent_owner_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'The owner of a record cannot be changed';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 2. Profiles and settings (one row per user)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 80),
  time_zone    text not null default 'UTC' check (char_length(time_zone) <= 64),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  units_weight           text not null default 'kg'  check (units_weight in ('kg','lb')),
  units_length           text not null default 'cm'  check (units_length in ('cm','in')),
  units_volume           text not null default 'ml'  check (units_volume in ('ml','oz')),
  time_format            text not null default '12'  check (time_format in ('12','24')),
  theme                  text not null default 'auto' check (theme in ('auto','light','dark')),
  calorie_target         numeric(6,0) check (calorie_target between 0 and 10000),
  protein_target         numeric(5,0) check (protein_target between 0 and 1000),
  carbs_target           numeric(5,0) check (carbs_target between 0 and 2000),
  fat_target             numeric(5,0) check (fat_target between 0 and 1000),
  water_goal_ml          numeric(6,0) not null default 2500 check (water_goal_ml between 0 and 20000),
  bed_time               time not null default '22:30',
  wake_time              time not null default '06:30',
  workouts_per_week_goal smallint not null default 4 check (workouts_per_week_goal between 0 and 14),
  goal                   text not null default 'maintain' check (goal in ('lose','maintain','gain','energy')),
  diet                   text[] not null default '{}',
  allergies              text check (char_length(allergies) <= 300),
  dislikes               text check (char_length(dislikes) <= 300),
  quiet_start            time,
  quiet_end              time,
  wind_down_min          smallint not null default 30 check (wind_down_min between 0 and 240),
  water_reminder_hours   numeric(3,1) not null default 0 check (water_reminder_hours between 0 and 12),
  browser_notifications  boolean not null default false,
  auto_reminders         boolean not null default true,
  height_cm              numeric(5,1) check (height_cm between 50 and 275),
  age                    smallint check (age between 5 and 120),
  sex                    text check (sex in ('female','male','other')),
  activity               text not null default 'moderate' check (activity in ('sedentary','light','moderate','active','very_active')),
  start_weight_kg        numeric(6,2) check (start_weight_kg between 20 and 500),
  goal_weight_kg         numeric(6,2) check (goal_weight_kg between 20 and 500),
  onboarded              boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- Create a profile + settings row automatically when someone signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80), ''))
  on conflict (id) do nothing;
  insert into public.user_settings (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. User data tables
--    Every table: id, user_id (owner, defaults to the signed-in user), is_demo (sample data flag),
--    timestamps, and (id, user_id) unique so child tables can use composite foreign keys
--    (a child row can only ever point at a parent owned by the same user).
-- ---------------------------------------------------------------------

-- Daily routine -------------------------------------------------------
create table if not exists public.routine_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  title      text not null check (char_length(title) between 1 and 120),
  category   text not null default 'other' check (category in ('wake','meal','workout','recovery','supplement','water','sleep','other')),
  item_time  time not null,
  days       smallint[] not null default '{0,1,2,3,4,5,6}' check (cardinality(days) > 0 and days <@ array[0,1,2,3,4,5,6]::smallint[]),
  notes      text check (char_length(notes) <= 1000),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.routine_log (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  item_id    uuid not null,
  log_date   date not null,
  status     text not null check (status in ('done','skipped','postponed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (item_id, log_date),
  foreign key (item_id, user_id) references public.routine_items(id, user_id) on delete cascade
);

-- Workouts ------------------------------------------------------------
create table if not exists public.workouts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo       boolean not null default false,
  title         text not null check (char_length(title) between 1 and 80),
  workout_date  date not null,
  start_time    time,
  duration_min  numeric(5,0) check (duration_min between 1 and 600),
  type          text not null default 'strength' check (type in ('strength','cardio','hiit','yoga','walking','running','cycling','swimming','sports','stretching','other')),
  location      text not null default 'gym' check (location in ('gym','home','outdoor','other')),
  muscle_groups text[] not null default '{}',
  effort        smallint check (effort between 1 and 10),
  status        text not null default 'planned' check (status in ('planned','done','skipped')),
  notes         text check (char_length(notes) <= 1000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.workout_exercises (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo       boolean not null default false,
  workout_id    uuid not null,
  exercise_name text not null check (char_length(exercise_name) between 1 and 120),
  sets          smallint not null check (sets between 1 and 50),
  reps          numeric(5,0) not null check (reps between 1 and 10000),
  weight_kg     numeric(7,2) check (weight_kg between 0 and 2000),
  rest_sec      numeric(5,0) check (rest_sec between 0 and 3600),
  notes         text check (char_length(notes) <= 500),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (id, user_id),
  foreign key (workout_id, user_id) references public.workouts(id, user_id) on delete cascade
);

create table if not exists public.custom_exercises (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo      boolean not null default false,
  name         text not null check (char_length(name) between 1 and 120),
  muscle_group text not null default 'full body' check (muscle_group in ('chest','back','shoulders','arms','legs','core','cardio','full body')),
  notes        text check (char_length(notes) <= 500),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.equipment (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  name       text not null check (char_length(name) between 1 and 80),
  quantity   smallint not null default 1 check (quantity between 0 and 1000),
  weight_kg  numeric(7,2) check (weight_kg between 0 and 2000),
  owned      boolean not null default true,
  notes      text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

-- Nutrition -----------------------------------------------------------
create table if not exists public.foods (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  name       text not null check (char_length(name) between 1 and 120),
  serving    text check (char_length(serving) <= 80),
  calories   numeric(7,1) check (calories between 0 and 10000),
  protein_g  numeric(6,1) check (protein_g between 0 and 2000),
  carbs_g    numeric(6,1) check (carbs_g between 0 and 2000),
  fat_g      numeric(6,1) check (fat_g between 0 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.meals (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  meal_date  date not null,
  meal_time  time,
  meal_type  text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  food_name  text not null check (char_length(food_name) between 1 and 120),
  portion    text check (char_length(portion) <= 80),
  calories   numeric(7,1) check (calories between 0 and 10000),
  protein_g  numeric(6,1) check (protein_g between 0 and 2000),
  carbs_g    numeric(6,1) check (carbs_g between 0 and 2000),
  fat_g      numeric(6,1) check (fat_g between 0 and 2000),
  notes      text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.meal_plans (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  weekday    smallint not null check (weekday between 0 and 6),
  meal_type  text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  food_name  text not null check (char_length(food_name) between 1 and 120),
  notes      text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.grocery_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  name       text not null check (char_length(name) between 1 and 120),
  checked    boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.water_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  log_date   date not null,
  log_time   time,
  amount_ml  numeric(6,0) not null check (amount_ml > 0 and amount_ml <= 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

-- Sleep ---------------------------------------------------------------
create table if not exists public.sleep_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  sleep_date date not null,                         -- the date you woke up
  bed_at     timestamptz not null,
  wake_at    timestamptz not null,
  quality    smallint check (quality between 1 and 5),
  is_nap     boolean not null default false,
  notes      text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  check (wake_at > bed_at and wake_at - bed_at <= interval '20 hours')
);

-- Recovery ------------------------------------------------------------
create table if not exists public.recovery_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo      boolean not null default false,
  session_date date not null,
  type         text not null check (type in ('massage','foam rolling','stretching','mobility','sauna / steam','ice bath','meditation','breathing','skincare','other')),
  duration_min numeric(5,0) check (duration_min between 1 and 600),
  body_area    text check (char_length(body_area) <= 80),
  notes        text check (char_length(notes) <= 500),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.soreness_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  log_date   date not null,
  body_area  text not null check (char_length(body_area) between 1 and 80),
  level      smallint not null check (level between 0 and 10),
  notes      text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

-- Supplements / medicines (tracking and reminders only) ----------------
create table if not exists public.supplements (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  name       text not null check (char_length(name) between 1 and 120),
  dose       numeric(8,2) check (dose >= 0 and dose <= 100000),
  unit       text check (char_length(unit) <= 20),
  times      text[] not null default '{}',
  days       smallint[] not null default '{0,1,2,3,4,5,6}' check (cardinality(days) > 0 and days <@ array[0,1,2,3,4,5,6]::smallint[]),
  notes      text check (char_length(notes) <= 500),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.supplement_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo       boolean not null default false,
  supplement_id uuid not null,
  log_date      date not null,
  status        text not null check (status in ('taken','skipped')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (id, user_id),
  unique (supplement_id, log_date),
  foreign key (supplement_id, user_id) references public.supplements(id, user_id) on delete cascade
);

-- Body ------------------------------------------------------------------
create table if not exists public.body_measurements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo      boolean not null default false,
  measure_date date not null,
  weight_kg    numeric(6,2) check (weight_kg between 20 and 500),
  body_fat_pct numeric(4,1) check (body_fat_pct between 2 and 80),
  waist_cm     numeric(5,1) check (waist_cm between 20 and 300),
  chest_cm     numeric(5,1) check (chest_cm between 20 and 300),
  hips_cm      numeric(5,1) check (hips_cm between 20 and 300),
  arm_cm       numeric(5,1) check (arm_cm between 5 and 100),
  thigh_cm     numeric(5,1) check (thigh_cm between 10 and 150),
  resting_hr   smallint check (resting_hr between 20 and 250),
  systolic     smallint check (systolic between 40 and 300),
  diastolic    smallint check (diastolic between 20 and 200),
  notes        text check (char_length(notes) <= 500),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, user_id)
);

-- Habits and check-ins ------------------------------------------------------
create table if not exists public.habits (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo         boolean not null default false,
  name            text not null check (char_length(name) between 1 and 80),
  target_per_week smallint not null default 7 check (target_per_week between 1 and 7),
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.habit_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo    boolean not null default false,
  habit_id   uuid not null,
  log_date   date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (habit_id, log_date),
  foreign key (habit_id, user_id) references public.habits(id, user_id) on delete cascade
);

create table if not exists public.daily_checkins (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo      boolean not null default false,
  checkin_date date not null,
  mood         smallint check (mood between 1 and 5),
  energy       smallint check (energy between 1 and 5),
  stress       smallint check (stress between 1 and 5),
  note         text check (char_length(note) <= 1000),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, checkin_date)
);

-- Reminders -------------------------------------------------------------
create table if not exists public.reminders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  is_demo     boolean not null default false,
  title       text not null check (char_length(title) between 1 and 120),
  category    text not null default 'other' check (category in ('workout','meal','water','supplement','sleep','wake','recovery','other')),
  remind_time time not null,
  days        smallint[] not null default '{0,1,2,3,4,5,6}' check (cardinality(days) > 0 and days <@ array[0,1,2,3,4,5,6]::smallint[]),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, user_id)
);

-- ---------------------------------------------------------------------
-- 4. Indexes for the most common lookups
-- ---------------------------------------------------------------------
create index if not exists workouts_user_date_idx          on public.workouts (user_id, workout_date);
create index if not exists workout_exercises_workout_idx   on public.workout_exercises (workout_id);
create index if not exists meals_user_date_idx             on public.meals (user_id, meal_date);
create index if not exists water_logs_user_date_idx        on public.water_logs (user_id, log_date);
create index if not exists sleep_logs_user_date_idx        on public.sleep_logs (user_id, sleep_date);
create index if not exists recovery_sessions_user_date_idx on public.recovery_sessions (user_id, session_date);
create index if not exists soreness_logs_user_date_idx     on public.soreness_logs (user_id, log_date);
create index if not exists body_measurements_user_date_idx on public.body_measurements (user_id, measure_date);
create index if not exists routine_log_user_date_idx       on public.routine_log (user_id, log_date);
create index if not exists supplement_logs_user_date_idx   on public.supplement_logs (user_id, log_date);
create index if not exists habit_logs_user_date_idx        on public.habit_logs (user_id, log_date);
create index if not exists daily_checkins_user_date_idx    on public.daily_checkins (user_id, checkin_date);

-- ---------------------------------------------------------------------
-- 5. Row Level Security, privileges and triggers for every user table
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  owner_tables text[] := array[
    'user_settings','routine_items','routine_log','workouts','workout_exercises','custom_exercises',
    'equipment','foods','meals','meal_plans','grocery_items','water_logs','sleep_logs',
    'recovery_sessions','soreness_logs','supplements','supplement_logs','body_measurements',
    'habits','habit_logs','daily_checkins','reminders'
  ];
begin
  foreach t in array owner_tables loop
    execute format('alter table public.%I enable row level security', t);

    -- No access at all for anonymous visitors; signed-in users get CRUD limited by the policies below.
    execute format('revoke all on table public.%I from anon', t);
    execute format('grant select, insert, update, delete on table public.%I to authenticated', t);

    execute format('drop policy if exists "owner can select" on public.%I', t);
    execute format('drop policy if exists "owner can insert" on public.%I', t);
    execute format('drop policy if exists "owner can update" on public.%I', t);
    execute format('drop policy if exists "owner can delete" on public.%I', t);

    execute format('create policy "owner can select" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy "owner can insert" on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t);
    execute format('create policy "owner can update" on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
    execute format('create policy "owner can delete" on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t);

    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', t || '_set_updated_at', t);

    execute format('drop trigger if exists %I on public.%I', t || '_no_owner_change', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.prevent_owner_change()', t || '_no_owner_change', t);
  end loop;
end $$;

-- profiles uses "id" as the owner column, so its policies are written out explicitly.
alter table public.profiles enable row level security;
revoke all on table public.profiles from anon;
grant select, insert, update, delete on table public.profiles to authenticated;

drop policy if exists "owner can select" on public.profiles;
drop policy if exists "owner can insert" on public.profiles;
drop policy if exists "owner can update" on public.profiles;
drop policy if exists "owner can delete" on public.profiles;
create policy "owner can select" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "owner can insert" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "owner can update" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "owner can delete" on public.profiles for delete to authenticated using (id = (select auth.uid()));

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 6. Account deletion (called from Settings -> Delete my account)
--    Deleting the auth user cascades to every table above.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;

-- Done. Next: configure Auth URLs (see README.md), then put your project URL and
-- publishable/anon key into index.html.
