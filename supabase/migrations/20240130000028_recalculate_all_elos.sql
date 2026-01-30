-- RECALCULATE ALL ELOS based on win rate
-- Formula: 1500 + (win_rate - 0.5) * 400
-- This gives ~1700 for 100% win rate, ~1300 for 0% win rate, ~1500 for 50%

UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500
    ELSE ROUND(1500 + ((wins::float / total_votes) - 0.5) * 400)
  END;

-- Now set Blockchain at Berkeley to #1 as requested
UPDATE clubs SET
  elo_rating = 1680
WHERE name = 'Blockchain at Berkeley';
