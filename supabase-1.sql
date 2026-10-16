-- ============================================================================
-- همیار زندگی — Supabase Schema, RLS, Storage & Functions
-- این فایل را یک‌جا در Supabase SQL Editor اجرا کنید (Run).
-- ترتیب اجرا مهم است و در همین فایل رعایت شده.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) Extensions
-- ----------------------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1) TABLES
-- ----------------------------------------------------------------------------

-- پروفایل کاربر (۱ به ۱ با auth.users)
create table if not exists public.profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_url text,
  gender text check (gender in ('male','female')),
  created_at timestamptz not null default now()
);

-- Migration-safe: اگر جدول قبلاً بدون این ستون ساخته شده
alter table public.profiles add column if not exists gender text check (gender in ('male','female'));

-- رابطه بین دو کاربر
create table if not exists public.relationships (
  id uuid primary key default uuid_generate_v4(),
  user1_id uuid not null references auth.users(id) on delete cascade,
  user2_id uuid references auth.users(id) on delete cascade,
  invite_code text unique not null,
  created_at timestamptz not null default now()
);

-- تسک‌ها
create table if not exists public.tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  relationship_id uuid references public.relationships(id) on delete set null,
  title text not null,
  description text default '',
  due_date date,
  due_time time,
  priority text not null default 'normal' check (priority in ('urgent','important','normal')),
  list_type text not null default 'work',
  completed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.subtasks (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  title text not null,
  completed boolean not null default false,
  order_index int not null default 0
);

create table if not exists public.tags (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  unique(user_id, name)
);

create table if not exists public.task_tags (
  task_id uuid not null references public.tasks(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  primary key (task_id, tag_id)
);

-- اهداف
create table if not exists public.goals (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  horizon text not null default '1m' check (horizon in ('1m','3m','6m','12m')),
  start_date date not null default current_date,
  deadline date,
  created_at timestamptz not null default now()
);

create table if not exists public.goal_steps (
  id uuid primary key default uuid_generate_v4(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  title text not null,
  completed boolean not null default false,
  order_index int not null default 0
);

-- Mood روزانه
create table if not exists public.moods (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  relationship_id uuid references public.relationships(id) on delete set null,
  mood int not null check (mood between 1 and 5),
  note text default '',
  is_shared boolean not null default false,
  mood_date date not null default current_date,
  created_at timestamptz not null default now(),
  unique(user_id, mood_date)
);

-- خاطرات مشترک
create table if not exists public.memories (
  id uuid primary key default uuid_generate_v4(),
  relationship_id uuid not null references public.relationships(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  memory_date date not null default current_date,
  image_url text,
  location text,
  tag text,
  created_at timestamptz not null default now()
);

-- چالش‌های مشترک
create table if not exists public.challenges (
  id uuid primary key default uuid_generate_v4(),
  relationship_id uuid not null references public.relationships(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  target int not null default 1,
  progress int not null default 0,
  start_date date not null default current_date,
  end_date date,
  completed boolean not null default false
);

-- چرخه‌های قاعدگی — هر ردیف یک چرخه واقعی است (نه فقط یک تنظیم ثابت)
create table if not exists public.cycles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  end_date date,
  cycle_length int,
  period_length int,
  is_shared boolean not null default false,
  notes text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Migration-safe: اگر این جدول قبلاً با نسخه قدیمی (تک‌ردیفی) ساخته شده،
-- این خط‌ها بدون آسیب به داده موجود، آن را به مدل «تاریخچه چرخه‌ها» ارتقا می‌دهند.
alter table public.cycles add column if not exists end_date date;
alter table public.cycles add column if not exists notes text default '';
alter table public.cycles add column if not exists updated_at timestamptz not null default now();
alter table public.cycles alter column cycle_length drop not null;
alter table public.cycles alter column cycle_length drop default;
alter table public.cycles alter column period_length drop not null;
alter table public.cycles alter column period_length drop default;

-- ثبت روزانه علائم و وضعیت چرخه — کاملاً خصوصی، حتی از پارتنر
create table if not exists public.cycle_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null default current_date,
  symptoms text[] not null default '{}',
  pain_level int check (pain_level between 0 and 10),
  energy_level int check (energy_level between 1 and 5),
  mood_today int check (mood_today between 1 and 5),
  note text default '',
  created_at timestamptz not null default now(),
  unique(user_id, log_date)
);

-- پیام‌های روزانه بین دو نفر رابطه — حداکثر ۳ پیام از هرکس در روز
create table if not exists public.daily_messages (
  id uuid primary key default uuid_generate_v4(),
  relationship_id uuid not null references public.relationships(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_date date not null default current_date,
  content text not null,
  created_at timestamptz not null default now()
);

-- Session های Pomodoro
create table if not exists public.pomodoro_sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  duration int not null,
  session_type text not null check (session_type in ('focus','break')),
  completed boolean not null default false,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

-- لاگ فعالیت (برای Streak)
create table if not exists public.activity_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  activity_date date not null default current_date
);

-- ----------------------------------------------------------------------------
-- 2) INDEXES
-- ----------------------------------------------------------------------------
create index if not exists idx_tasks_user on public.tasks(user_id);
create index if not exists idx_tasks_due on public.tasks(due_date);
create index if not exists idx_subtasks_task on public.subtasks(task_id);
create index if not exists idx_goals_user on public.goals(user_id);
create index if not exists idx_goal_steps_goal on public.goal_steps(goal_id);
create index if not exists idx_moods_user_date on public.moods(user_id, mood_date);
create index if not exists idx_memories_rel on public.memories(relationship_id);
create index if not exists idx_challenges_rel on public.challenges(relationship_id);
create index if not exists idx_activity_user_date on public.activity_logs(user_id, activity_date);
create index if not exists idx_relationships_users on public.relationships(user1_id, user2_id);
create index if not exists idx_cycles_user_start on public.cycles(user_id, start_date);
create index if not exists idx_cycle_logs_user_date on public.cycle_logs(user_id, log_date);
create index if not exists idx_daily_messages_rel_date on public.daily_messages(relationship_id, message_date);

-- ----------------------------------------------------------------------------
-- 3) HELPER FUNCTIONS
-- ----------------------------------------------------------------------------

-- آیا کاربر جاری در این relationship عضو است؟
create or replace function public.is_relationship_member(rel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.relationships r
    where r.id = rel_id
      and (r.user1_id = auth.uid() or r.user2_id = auth.uid())
  );
$$;

-- پارتنر کاربر جاری در یک relationship را برمی‌گرداند
create or replace function public.partner_id_of(rel_id uuid)
returns uuid
language sql
security definer
stable
as $$
  select case
    when r.user1_id = auth.uid() then r.user2_id
    when r.user2_id = auth.uid() then r.user1_id
    else null
  end
  from public.relationships r where r.id = rel_id;
$$;

-- تولید کد دعوت ۶ کاراکتری یکتا
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  code text;
  exists_code boolean;
begin
  loop
    code := upper(substr(md5(random()::text), 1, 6));
    select exists(select 1 from public.relationships where invite_code = code) into exists_code;
    exit when not exists_code;
  end loop;
  return code;
end;
$$;

-- ایجاد رابطه جدید برای کاربر جاری (تک‌نفره تا اتصال partner)
create or replace function public.create_relationship()
returns public.relationships
language plpgsql
security definer
as $$
declare
  new_rel public.relationships;
begin
  insert into public.relationships (user1_id, invite_code)
  values (auth.uid(), public.generate_invite_code())
  returning * into new_rel;
  return new_rel;
end;
$$;

-- اتصال به یک relationship با کد دعوت
create or replace function public.join_relationship(p_code text)
returns public.relationships
language plpgsql
security definer
as $$
declare
  rel public.relationships;
begin
  select * into rel from public.relationships where invite_code = upper(p_code);
  if rel.id is null then
    raise exception 'کد دعوت نامعتبر است';
  end if;
  if rel.user2_id is not null then
    raise exception 'این کد قبلاً استفاده شده است';
  end if;
  if rel.user1_id = auth.uid() then
    raise exception 'نمی‌توانید با کد خودتان متصل شوید';
  end if;
  update public.relationships set user2_id = auth.uid() where id = rel.id
  returning * into rel;
  return rel;
end;
$$;

-- محاسبه Streak کاربر بر اساس activity_logs
create or replace function public.get_streak(p_user_id uuid)
returns int
language plpgsql
stable
as $$
declare
  streak int := 0;
  cur_date date := current_date;
  has_activity boolean;
begin
  loop
    select exists(
      select 1 from public.activity_logs
      where user_id = p_user_id and activity_date = cur_date
    ) into has_activity;
    exit when not has_activity;
    streak := streak + 1;
    cur_date := cur_date - 1;
  end loop;
  return streak;
end;
$$;

-- سقف ۳ پیام روزانه از هرکس — این محدودیت در سطح دیتابیس اعمال می‌شود،
-- نه فقط با مخفی‌کردن دکمه در UI، تا هیچ‌کس نتواند آن را دور بزند.
create or replace function public.enforce_daily_message_limit()
returns trigger
language plpgsql
security definer
as $$
declare
  msg_count int;
begin
  select count(*) into msg_count
  from public.daily_messages
  where relationship_id = new.relationship_id
    and sender_id = new.sender_id
    and message_date = new.message_date;
  if msg_count >= 3 then
    raise exception 'سقف ۳ پیام امروز پر شده — فردا دوباره تلاش کن.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_daily_message_limit on public.daily_messages;
create trigger trg_daily_message_limit
  before insert on public.daily_messages
  for each row execute procedure public.enforce_daily_message_limit();

-- ----------------------------------------------------------------------------
-- 4) TRIGGERS
-- ----------------------------------------------------------------------------

-- ساخت خودکار پروفایل هنگام ثبت‌نام
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (user_id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 5) ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.relationships enable row level security;
alter table public.tasks enable row level security;
alter table public.subtasks enable row level security;
alter table public.tags enable row level security;
alter table public.task_tags enable row level security;
alter table public.goals enable row level security;
alter table public.goal_steps enable row level security;
alter table public.moods enable row level security;
alter table public.memories enable row level security;
alter table public.challenges enable row level security;
alter table public.cycles enable row level security;
alter table public.cycle_logs enable row level security;
alter table public.daily_messages enable row level security;
alter table public.pomodoro_sessions enable row level security;
alter table public.activity_logs enable row level security;

-- profiles: هرکس فقط پروفایل خودش را می‌بیند/ویرایش می‌کند، اما پروفایل پارتنر هم قابل خواندن باشد
drop policy if exists "profiles_select_own_or_partner" on public.profiles;
create policy "profiles_select_own_or_partner" on public.profiles
  for select using (
    user_id = auth.uid()
    or user_id in (
      select case when user1_id = auth.uid() then user2_id else user1_id end
      from public.relationships
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  );
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (user_id = auth.uid());
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert with check (user_id = auth.uid());

-- relationships: فقط اعضای رابطه
drop policy if exists "relationships_select_member" on public.relationships;
create policy "relationships_select_member" on public.relationships
  for select using (user1_id = auth.uid() or user2_id = auth.uid());
drop policy if exists "relationships_insert_self" on public.relationships;
create policy "relationships_insert_self" on public.relationships
  for insert with check (user1_id = auth.uid());
drop policy if exists "relationships_update_member" on public.relationships;
create policy "relationships_update_member" on public.relationships
  for update using (user1_id = auth.uid() or user2_id = auth.uid());

-- tasks: فقط صاحب task
drop policy if exists "tasks_all_own" on public.tasks;
create policy "tasks_all_own" on public.tasks
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- subtasks: از طریق task مالکیت بررسی می‌شود
drop policy if exists "subtasks_all_via_task" on public.subtasks;
create policy "subtasks_all_via_task" on public.subtasks
  for all using (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()))
  with check (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()));

-- tags: فقط صاحب
drop policy if exists "tags_all_own" on public.tags;
create policy "tags_all_own" on public.tags
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- task_tags: از طریق task
drop policy if exists "task_tags_all_via_task" on public.task_tags;
create policy "task_tags_all_via_task" on public.task_tags
  for all using (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()))
  with check (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()));

-- goals: فقط صاحب
drop policy if exists "goals_all_own" on public.goals;
create policy "goals_all_own" on public.goals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- goal_steps: از طریق goal
drop policy if exists "goal_steps_all_via_goal" on public.goal_steps;
create policy "goal_steps_all_via_goal" on public.goal_steps
  for all using (exists(select 1 from public.goals g where g.id = goal_id and g.user_id = auth.uid()))
  with check (exists(select 1 from public.goals g where g.id = goal_id and g.user_id = auth.uid()));

-- moods: خودش همیشه، پارتنر فقط اگر is_shared = true
drop policy if exists "moods_select_own_or_shared" on public.moods;
create policy "moods_select_own_or_shared" on public.moods
  for select using (
    user_id = auth.uid()
    or (is_shared = true and relationship_id is not null and public.is_relationship_member(relationship_id))
  );
drop policy if exists "moods_insert_own" on public.moods;
create policy "moods_insert_own" on public.moods for insert with check (user_id = auth.uid());
drop policy if exists "moods_update_own" on public.moods;
create policy "moods_update_own" on public.moods for update using (user_id = auth.uid());
drop policy if exists "moods_delete_own" on public.moods;
create policy "moods_delete_own" on public.moods for delete using (user_id = auth.uid());

-- memories: هر دو عضو رابطه دسترسی کامل دارند (مشترک هستند)
drop policy if exists "memories_all_relationship_member" on public.memories;
create policy "memories_all_relationship_member" on public.memories
  for all using (public.is_relationship_member(relationship_id))
  with check (public.is_relationship_member(relationship_id));

-- challenges: هر دو عضو رابطه
drop policy if exists "challenges_all_relationship_member" on public.challenges;
create policy "challenges_all_relationship_member" on public.challenges
  for all using (public.is_relationship_member(relationship_id))
  with check (public.is_relationship_member(relationship_id));

-- daily_messages: هر دو عضو رابطه می‌بینند، ولی فقط خودت می‌فرستی/حذف می‌کنی
drop policy if exists "daily_messages_select_member" on public.daily_messages;
create policy "daily_messages_select_member" on public.daily_messages
  for select using (public.is_relationship_member(relationship_id));
drop policy if exists "daily_messages_insert_own" on public.daily_messages;
create policy "daily_messages_insert_own" on public.daily_messages
  for insert with check (sender_id = auth.uid() and public.is_relationship_member(relationship_id));
drop policy if exists "daily_messages_delete_own" on public.daily_messages;
create policy "daily_messages_delete_own" on public.daily_messages
  for delete using (sender_id = auth.uid());

-- cycles: کاملاً خصوصی مگر share شود (فقط select برای پارتنر)
drop policy if exists "cycles_select_own_or_shared_partner" on public.cycles;
create policy "cycles_select_own_or_shared_partner" on public.cycles
  for select using (
    user_id = auth.uid()
    or (
      is_shared = true
      and exists (
        select 1 from public.relationships r
        where (r.user1_id = auth.uid() and r.user2_id = cycles.user_id)
           or (r.user2_id = auth.uid() and r.user1_id = cycles.user_id)
      )
    )
  );
drop policy if exists "cycles_insert_own" on public.cycles;
create policy "cycles_insert_own" on public.cycles for insert with check (user_id = auth.uid());
drop policy if exists "cycles_update_own" on public.cycles;
create policy "cycles_update_own" on public.cycles for update using (user_id = auth.uid());
drop policy if exists "cycles_delete_own" on public.cycles;
create policy "cycles_delete_own" on public.cycles for delete using (user_id = auth.uid());

-- cycle_logs: کاملاً خصوصی، حتی پارتنر هم نمی‌تواند ببیند
drop policy if exists "cycle_logs_all_own" on public.cycle_logs;
create policy "cycle_logs_all_own" on public.cycle_logs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- pomodoro_sessions: فقط صاحب
drop policy if exists "pomodoro_all_own" on public.pomodoro_sessions;
create policy "pomodoro_all_own" on public.pomodoro_sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- activity_logs: فقط صاحب
drop policy if exists "activity_all_own" on public.activity_logs;
create policy "activity_all_own" on public.activity_logs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 6) STORAGE BUCKETS & POLICIES
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('memory-images', 'memory-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- هر کاربر لاگین‌شده می‌تواند در پوشه‌ای با نام user_id خودش آپلود کند
drop policy if exists "memory_images_insert_own_folder" on storage.objects;
create policy "memory_images_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'memory-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
drop policy if exists "memory_images_select_public" on storage.objects;
create policy "memory_images_select_public" on storage.objects
  for select using (bucket_id = 'memory-images');
drop policy if exists "memory_images_delete_own_folder" on storage.objects;
create policy "memory_images_delete_own_folder" on storage.objects
  for delete using (
    bucket_id = 'memory-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_insert_own_folder" on storage.objects;
create policy "avatars_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
drop policy if exists "avatars_select_public" on storage.objects;
create policy "avatars_select_public" on storage.objects
  for select using (bucket_id = 'avatars');
drop policy if exists "avatars_update_own_folder" on storage.objects;
create policy "avatars_update_own_folder" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
drop policy if exists "avatars_delete_own_folder" on storage.objects;
create policy "avatars_delete_own_folder" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ----------------------------------------------------------------------------
-- 7) REALTIME
-- ----------------------------------------------------------------------------
-- alter publication ... add table می‌دهد خطا اگر جدول از قبل عضو Publication باشد؛
-- این تابع کمکی آن را Idempotent می‌کند تا اجرای دوباره اسکریپت مشکلی ایجاد نکند.
do $$
declare
  t text;
begin
  foreach t in array array['moods','memories','challenges','daily_messages'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ============================================================================
-- پایان اسکریپت. بعد از اجرا:
-- ۱) از Authentication > Settings مطمئن شوید Email confirmations مطابق نیازتان تنظیم است.
-- ۲) Bucketهای memory-images و avatars را در Storage بررسی کنید.
-- ============================================================================
