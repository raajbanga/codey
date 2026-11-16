-- App content (Nov 15): topics, quiz questions, coding exercises and
-- starter decks live here and are edited in the dashboard. The app reads
-- them at launch (signed in or not), checks them, and keeps the last good
-- copy; the bundled JSON is only the first-launch / offline fallback.
-- Read-only through the API: no insert/update/delete policies.

create table public.content_topics (
    id text primary key,
    title text not null,
    summary text not null,
    icon_name text not null,
    sort_index int not null default 0
);

create table public.content_questions (
    id text primary key,
    topic_id text not null references public.content_topics (id) on delete cascade,
    prompt text not null,
    options text[] not null check (cardinality(options) between 2 and 6),
    correct_option_index int not null,
    explanation text not null,
    difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
    sort_index int not null default 0,
    check (correct_option_index >= 0 and correct_option_index < cardinality(options))
);

-- blanks: [{"accepted": ["guard"]}, ...], one per ___ in code.
create table public.content_exercises (
    id text primary key,
    topic_id text not null references public.content_topics (id) on delete cascade,
    title text not null,
    language text not null,
    prompt text not null,
    code text not null,
    blanks jsonb not null check (jsonb_typeof(blanks) = 'array'),
    explanation text not null,
    sort_index int not null default 0
);

create table public.content_decks (
    starter_key text primary key,
    topic_id text not null references public.content_topics (id) on delete cascade,
    title text not null,
    sort_index int not null default 0
);

create table public.content_cards (
    id text primary key,
    deck_key text not null references public.content_decks (starter_key) on delete cascade,
    prompt text not null,
    answer text not null,
    difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
    code_language text,
    code_source text,
    sort_index int not null default 0,
    check ((code_language is null) = (code_source is null))
);

create index content_questions_topic on public.content_questions (topic_id);
create index content_exercises_topic on public.content_exercises (topic_id);
create index content_decks_topic on public.content_decks (topic_id);
create index content_cards_deck on public.content_cards (deck_key);

alter table public.content_topics enable row level security;
alter table public.content_questions enable row level security;
alter table public.content_exercises enable row level security;
alter table public.content_decks enable row level security;
alter table public.content_cards enable row level security;

create policy "content is public" on public.content_topics for select to anon, authenticated using (true);
create policy "content is public" on public.content_questions for select to anon, authenticated using (true);
create policy "content is public" on public.content_exercises for select to anon, authenticated using (true);
create policy "content is public" on public.content_decks for select to anon, authenticated using (true);
create policy "content is public" on public.content_cards for select to anon, authenticated using (true);

comment on table public.content_topics is 'Quiz topics. Read by the app at launch; edit here.';
comment on table public.content_questions is 'Quiz questions (multiple choice). correct_option_index is 0-based.';
comment on table public.content_exercises is 'Fill-in-the-blank coding exercises. Each ___ in code is one blank; blanks = [{"accepted": [...]}].';
comment on table public.content_decks is 'Starter flashcard decks. starter_key is the stable id; never rename it.';
comment on table public.content_cards is 'Starter deck cards. id is stable: keep it, or learners lose their progress on the card.';
