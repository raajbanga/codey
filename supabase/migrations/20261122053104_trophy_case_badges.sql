-- The trophy case (Nov 21): 27 badges instead of 4. badge_awards accepts
-- exactly the app's Badge raw values (SupabaseSchemaTests checks them),
-- so an older build's badges stay valid and a newer build's sync isn't
-- rejected. Badge XP is paid on the device that earns the badge and syncs
-- through profiles.total_xp (max-merged); nothing else changes.

alter table public.badge_awards drop constraint badge_awards_badge_check;
alter table public.badge_awards add constraint badge_awards_badge_check
    check (badge in ('level2', 'level5', 'level10', 'level20', 'xp1000', 'sevenDayStreak', 'streak30', 'dailyGoal10', 'weeklyChallenge', 'correct50', 'correct250', 'correct1000', 'hardTier', 'topic1', 'topics4', 'drill1', 'drills5', 'drills10', 'challenge1', 'challenges5', 'firstDeck', 'deck1', 'decks5', 'decks10', 'cards20', 'cards50', 'cards100'));
