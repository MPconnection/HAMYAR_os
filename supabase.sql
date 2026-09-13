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
  created_at timestamptz not null default now()
);

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

-- چرخه ماهانه (کاملاً خصوصی مگر share شود)
create table if not exists public.cycles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  cycle_length int not null default 28,
  period_length int not null default 6,
  is_shared boolean not null default false,
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
alter table public.pomodoro_sessions enable row level security;
alter table public.activity_logs enable row level security;

-- profiles: هرکس فقط پروفایل خودش را می‌بیند/ویرایش می‌کند، اما پروفایل پارتنر هم قابل خواندن باشد
create policy "profiles_select_own_or_partner" on public.profiles
  for select using (
    user_id = auth.uid()
    or user_id in (
      select case when user1_id = auth.uid() then user2_id else user1_id end
      from public.relationships
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  );
create policy "profiles_update_own" on public.profiles for update using (user_id = auth.uid());
create policy "profiles_insert_own" on public.profiles for insert with check (user_id = auth.uid());

-- relationships: فقط اعضای رابطه
create policy "relationships_select_member" on public.relationships
  for select using (user1_id = auth.uid() or user2_id = auth.uid());
create policy "relationships_insert_self" on public.relationships
  for insert with check (user1_id = auth.uid());
create policy "relationships_update_member" on public.relationships
  for update using (user1_id = auth.uid() or user2_id = auth.uid());

-- tasks: فقط صاحب task
create policy "tasks_all_own" on public.tasks
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- subtasks: از طریق task مالکیت بررسی می‌شود
create policy "subtasks_all_via_task" on public.subtasks
  for all using (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()))
  with check (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()));

-- tags: فقط صاحب
create policy "tags_all_own" on public.tags
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- task_tags: از طریق task
create policy "task_tags_all_via_task" on public.task_tags
  for all using (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()))
  with check (exists(select 1 from public.tasks t where t.id = task_id and t.user_id = auth.uid()));

-- goals: فقط صاحب
create policy "goals_all_own" on public.goals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- goal_steps: از طریق goal
create policy "goal_steps_all_via_goal" on public.goal_steps
  for all using (exists(select 1 from public.goals g where g.id = goal_id and g.user_id = auth.uid()))
  with check (exists(select 1 from public.goals g where g.id = goal_id and g.user_id = auth.uid()));

-- moods: خودش همیشه، پارتنر فقط اگر is_shared = true
create policy "moods_select_own_or_shared" on public.moods
  for select using (
    user_id = auth.uid()
    or (is_shared = true and relationship_id is not null and public.is_relationship_member(relationship_id))
  );
create policy "moods_insert_own" on public.moods for insert with check (user_id = auth.uid());
create policy "moods_update_own" on public.moods for update using (user_id = auth.uid());
create policy "moods_delete_own" on public.moods for delete using (user_id = auth.uid());

-- memories: هر دو عضو رابطه دسترسی کامل دارند (مشترک هستند)
create policy "memories_all_relationship_member" on public.memories
  for all using (public.is_relationship_member(relationship_id))
  with check (public.is_relationship_member(relationship_id));

-- challenges: هر دو عضو رابطه
create policy "challenges_all_relationship_member" on public.challenges
  for all using (public.is_relationship_member(relationship_id))
  with check (public.is_relationship_member(relationship_id));

-- cycles: کاملاً خصوصی مگر share شود (فقط select برای پارتنر)
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
create policy "cycles_insert_own" on public.cycles for insert with check (user_id = auth.uid());
create policy "cycles_update_own" on public.cycles for update using (user_id = auth.uid());
create policy "cycles_delete_own" on public.cycles for delete using (user_id = auth.uid());

-- pomodoro_sessions: فقط صاحب
create policy "pomodoro_all_own" on public.pomodoro_sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- activity_logs: فقط صاحب
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
create policy "memory_images_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'memory-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "memory_images_select_public" on storage.objects
  for select using (bucket_id = 'memory-images');
create policy "memory_images_delete_own_folder" on storage.objects
  for delete using (
    bucket_id = 'memory-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "avatars_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "avatars_select_public" on storage.objects
  for select using (bucket_id = 'avatars');
create policy "avatars_update_own_folder" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "avatars_delete_own_folder" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ----------------------------------------------------------------------------
-- 7) REALTIME
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table public.moods;
alter publication supabase_realtime add table public.memories;
alter publication supabase_realtime add table public.challenges;

-- ============================================================================
-- پایان اسکریپت. بعد از اجرا:
-- ۱) از Authentication > Settings مطمئن شوید Email confirmations مطابق نیازتان تنظیم است.
-- ۲) Bucketهای memory-images و avatars را در Storage بررسی کنید.
-- ============================================================================
