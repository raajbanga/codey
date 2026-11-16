-- §3b: a card can be hidden from study without deleting it. Older app
-- versions never send the column, so the default keeps their cards visible.
alter table public.flashcards add column if not exists is_hidden boolean not null default false;
