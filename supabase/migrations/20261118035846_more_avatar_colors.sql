-- Nov 17: five more avatar colors (gold, green, indigo, violet, plum), the
-- topic hues added for the extra topics. Same rule as 20261115045606.
alter table public.profiles drop constraint if exists profiles_avatar_id_check;
alter table public.profiles add constraint profiles_avatar_id_check
    check (avatar_id is null or (
        split_part(avatar_id, '@', 1) in ('person.fill', 'star.fill', 'bolt.fill', 'leaf.fill', 'flame.fill', 'moon.fill', 'sun.max.fill', 'cloud.fill', 'hare.fill', 'tortoise.fill', 'brain.head.profile', 'terminal.fill', 'cat', 'dog', 'bird', 'fish', 'graduationcap', 'book', 'pencil', 'lightbulb', 'puzzlepiece', 'gamecontroller', 'atom', 'cpu', 'keyboard', 'globe.americas', 'music.note', 'paintpalette', 'trophy', 'heart', 'mountain.2', 'sparkles')
        and (strpos(avatar_id, '@') = 0 or split_part(avatar_id, '@', 2) in ('slate', 'teal', 'sky', 'olive', 'sand', 'coral', 'rose', 'gold', 'green', 'indigo', 'violet', 'plum'))
    ));
