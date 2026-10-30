-- Full schema for Note. Safe to run more than once. The part that adds folders is also kept on its own in
-- shell-apps/core/sql/002_folders.sql (run that alone if the notes table already exists).

-- Run once in the Supabase SQL editor (project "Apps").
-- Notes are scoped by note_code, the same idea as QuickSend's send code. Deleting a note
-- keeps its row with deleted = true so the delete reaches every device.

create table if not exists quick_notes (
  note_code text not null,
  id        text not null,
  text      text not null default '',
  pinned    boolean not null default false,
  updated   bigint not null,          -- epoch seconds of the last edit
  deleted   boolean not null default false,
  primary key (note_code, id)
);
create index if not exists quick_notes_updated on quick_notes (note_code, updated);

alter table quick_notes enable row level security;
drop policy if exists "public read notes" on quick_notes;
create policy "public read notes"   on quick_notes for select using (true);
drop policy if exists "public insert notes" on quick_notes;
create policy "public insert notes" on quick_notes for insert with check (true);
drop policy if exists "public update notes" on quick_notes;
create policy "public update notes" on quick_notes for update using (true);
drop policy if exists "public delete notes" on quick_notes;
create policy "public delete notes" on quick_notes for delete using (true);

-- A note's folder: '' = no folder, null = written by an older client that doesn't know about folders.
alter table quick_notes add column if not exists folder text;

create table if not exists quick_folders (
  note_code text not null,
  id        text not null,
  name      text not null default '',
  updated   bigint not null,          -- epoch seconds of the last rename
  deleted   boolean not null default false,
  primary key (note_code, id)
);
create index if not exists quick_folders_updated on quick_folders (note_code, updated);

alter table quick_folders enable row level security;
drop policy if exists "public read folders"   on quick_folders;
drop policy if exists "public insert folders" on quick_folders;
drop policy if exists "public update folders" on quick_folders;
drop policy if exists "public delete folders" on quick_folders;
create policy "public read folders"   on quick_folders for select using (true);
create policy "public insert folders" on quick_folders for insert with check (true);
create policy "public update folders" on quick_folders for update using (true);
create policy "public delete folders" on quick_folders for delete using (true);

-- Batch upsert for notes, now carrying the folder. An older client that sends no folder (null) keeps the
-- folder the server already has; '' really means "no folder".
create or replace function upsert_quick_notes(p_code text, p_notes jsonb)
returns void language sql as $$
  insert into quick_notes (note_code, id, text, pinned, updated, deleted, folder)
  select p_code, n.id, coalesce(n.text, ''), coalesce(n.pinned, false), n.updated, coalesce(n.deleted, false), n.folder
  from jsonb_to_recordset(p_notes) as n(id text, text text, pinned boolean, updated bigint, deleted boolean, folder text)
  on conflict (note_code, id) do update
    set text = excluded.text, pinned = excluded.pinned, updated = excluded.updated, deleted = excluded.deleted,
        folder = coalesce(excluded.folder, quick_notes.folder)
    where quick_notes.updated < excluded.updated;
$$;

create or replace function upsert_quick_folders(p_code text, p_folders jsonb)
returns void language sql as $$
  insert into quick_folders (note_code, id, name, updated, deleted)
  select p_code, f.id, coalesce(f.name, ''), f.updated, coalesce(f.deleted, false)
  from jsonb_to_recordset(p_folders) as f(id text, name text, updated bigint, deleted boolean)
  on conflict (note_code, id) do update
    set name = excluded.name, updated = excluded.updated, deleted = excluded.deleted
    where quick_folders.updated < excluded.updated;
$$;
