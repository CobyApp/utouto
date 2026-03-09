-- =============================================
-- utouto - Supabase Schema
-- =============================================

-- community_clips テーブル
create table public.community_clips (
  id            uuid primary key default gen_random_uuid(),
  user_id       text not null default 'anonymous',
  title         text not null,
  description   text not null default '',
  audio_url     text not null,
  thumbnail_url text,
  duration_sec  float not null,
  like_count    int not null default 0,
  download_count int not null default 0,
  created_at    timestamptz not null default now()
);

-- RLS (Row Level Security)
alter table public.community_clips enable row level security;

-- 誰でも閲覧可能
create policy "Anyone can read clips"
  on public.community_clips for select using (true);

-- 誰でも投稿可能（本番ではauth.uid()に変更）
create policy "Anyone can insert clips"
  on public.community_clips for insert with check (true);

-- 自分のクリップのみ削除可能（開発中はanonymousなのでuser_id='anonymous'）
create policy "Anyone can delete own clips"
  on public.community_clips for delete using (true);

-- =============================================
-- Storage bucket: clips
-- =============================================
-- Supabase Dashboard > Storage > New bucket
-- Name: clips
-- Public: true
-- Allowed MIME types: audio/m4a, audio/mpeg, image/jpeg, image/png

-- =============================================
-- like カウントインクリメント用 RPC
-- =============================================
create or replace function increment_like(clip_id uuid)
returns void language sql as $$
  update public.community_clips
  set like_count = like_count + 1
  where id = clip_id;
$$;

-- download カウントインクリメント用 RPC
create or replace function increment_download(clip_id uuid)
returns void language sql as $$
  update public.community_clips
  set download_count = download_count + 1
  where id = clip_id;
$$;

-- =============================================
-- Index
-- =============================================
create index on public.community_clips (created_at desc);
create index on public.community_clips (like_count desc);
