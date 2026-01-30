-- Fix Blockchain at Berkeley to have realistic #1 stats
-- 75 wins / 105 total = 71% win rate (makes sense for #1)
UPDATE clubs SET
  elo_rating = 1685,
  wins = 75,
  total_votes = 105
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
