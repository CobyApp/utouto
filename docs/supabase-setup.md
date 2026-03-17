# Supabase setup for うとうと (Utouto)

**한글 체크리스트:** [SUPABASE_할일.md](./SUPABASE_할일.md) 참고.

## Connection

- **SUPABASE_URL**: Set in `Info.plist` (or Xcode build settings). Use your project URL from Supabase Dashboard → Settings → API → Project URL.
- **SUPABASE_ANON_KEY**: Use the **anon public** key from Dashboard → Settings → API → Project API keys. It usually starts with `eyJ...` (JWT). Replace any placeholder in Info.plist.

## Storage bucket: `clips`

- Create a bucket named `clips`.
- **Public** bucket so `audio_url` and `thumbnail_url` are reachable.
- Policies (optional): allow public read; allow insert/update/delete only with auth if you add Supabase Auth later.

## Table: `community_clips`

```sql
create table if not exists community_clips (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  title text not null,
  description text default '',
  audio_url text not null,
  thumbnail_url text,
  duration_sec float8 not null,
  like_count int default 0,
  download_count int default 0,
  created_at timestamptz default now()
);

-- Optional: RLS so only the uploader can delete (by user_id)
alter table community_clips enable row level security;

create policy "Allow delete own clip"
  on community_clips for delete
  using (true);  -- For anon key we enforce "uploader only" in the app. With Supabase Auth you could use: auth.uid()::text = user_id
```

- **user_id**: Device-scoped id (UUID string) stored in the app; used so only the uploader sees the delete button and the app only calls delete for own clips.

## RPCs

### increment_like

```sql
create or replace function increment_like(clip_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update community_clips
  set like_count = like_count + 1
  where id = clip_id;
end;
$$;
```

### increment_download_count

```sql
create or replace function increment_download_count(clip_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update community_clips
  set download_count = download_count + 1
  where id = clip_id;
end;
$$;
```

Grant execute to anon if using RLS:

```sql
grant execute on function increment_like(uuid) to anon;
grant execute on function increment_download_count(uuid) to anon;
```

## Permissions summary

| Action           | Who                    | Note                          |
|------------------|------------------------|-------------------------------|
| SELECT           | Anyone (anon)          | List/search clips             |
| INSERT           | Anyone (anon)          | Upload; `user_id` = device id |
| DELETE           | Anyone (anon)          | App only calls for own clips  |
| Storage read     | Public                 | Audio/thumb URLs              |
| Storage upload   | Service role or policy | Upload from app               |

For production, consider enabling Supabase Auth (e.g. anonymous sign-in) and RLS so `user_id = auth.uid()::text` for delete.
