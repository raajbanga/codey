-- User decks and their cards (FR-05–13, FR-44–48). Ids are generated on the
-- client and equal the local SwiftData ids. Starter decks never sync.
--
-- LIMITS MUST MATCH ModelValidator.Limits and flashcard.schema.json
-- (FlashcardSchemaFileTests + SupabaseSchemaTests check them):
--   title 1–60, prompt 1–500, answer 1–500, code_source 1–2000 and ≤ 80 lines.
-- Lengths count characters after trimming whitespace/newlines, the same as
-- the validator (char_length counts Unicode code points = Swift scalars).

-- Pull cursor: set by the server on every write, never by the client.
create function public.set_server_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.server_updated_at := now();
    return new;
end;
$$;

create table public.decks (
    id                uuid primary key,
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    title             text not null check (char_length(btrim(title, E' \t\r\n')) between 1 and 60),
    topic_id          text not null check (char_length(topic_id) between 1 and 100),
    -- CLIENT clock; last-writer-wins compares these.
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    -- Tombstone, kept until every device has pulled the delete.
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.flashcards (
    id                uuid primary key,
    deck_id           uuid not null references public.decks (id) on delete cascade,
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    prompt            text not null check (char_length(btrim(prompt, E' \t\r\n')) between 1 and 500),
    answer            text not null check (char_length(btrim(answer, E' \t\r\n')) between 1 and 500),
    code_language     text check (code_language in ('swift', 'python', 'java', 'cpp')),
    code_source       text check (
        char_length(btrim(code_source, E' \t\r\n')) between 1 and 2000
        and array_length(string_to_array(btrim(code_source, E'\r\n'), E'\n'), 1) <= 80
    ),
    difficulty        text check (difficulty in ('easy', 'medium', 'hard')),
    sort_index        integer not null default 0 check (sort_index >= 0),
    created_at        timestamptz not null,
    updated_at        timestamptz not null,
    deleted_at        timestamptz,
    server_updated_at timestamptz not null default now(),
    -- A snippet has both a language and source, or neither (D2).
    constraint flashcards_snippet_complete check ((code_language is null) = (code_source is null))
);

create index decks_owner_cursor on public.decks (owner_id, server_updated_at);
create index flashcards_owner_cursor on public.flashcards (owner_id, server_updated_at);
create index flashcards_deck on public.flashcards (deck_id);

create trigger decks_set_server_updated_at
    before insert or update on public.decks
    for each row execute function public.set_server_updated_at();

create trigger flashcards_set_server_updated_at
    before insert or update on public.flashcards
    for each row execute function public.set_server_updated_at();
