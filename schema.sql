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
create policy "public read notes"   on quick_notes for select using (true);
create policy "public insert notes" on quick_notes for insert with check (true);
create policy "public update notes" on quick_notes for update using (true);
create policy "public delete notes" on quick_notes for delete using (true);

-- Batch upsert that never lets an older copy overwrite a newer one.
create or replace function upsert_quick_notes(p_code text, p_notes jsonb)
returns void language sql as $$
  insert into quick_notes (note_code, id, text, pinned, updated, deleted)
  select p_code, n.id, coalesce(n.text, ''), coalesce(n.pinned, false), n.updated, coalesce(n.deleted, false)
  from jsonb_to_recordset(p_notes) as n(id text, text text, pinned boolean, updated bigint, deleted boolean)
  on conflict (note_code, id) do update
    set text = excluded.text, pinned = excluded.pinned,
        updated = excluded.updated, deleted = excluded.deleted
    where quick_notes.updated < excluded.updated;
$$;
