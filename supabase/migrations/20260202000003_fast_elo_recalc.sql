-- Fast ELO recalculation using set-based operations
-- Since exact ELO order matters less than relative standings, we'll use a simplified approach

-- Step 1: Calculate wins and total_votes from matchups
WITH win_counts AS (
  SELECT winner_id as club_id, COUNT(*) as wins
  FROM matchups
  GROUP BY winner_id
),
loss_counts AS (
  SELECT
    CASE WHEN winner_id = club_a_id THEN club_b_id ELSE club_a_id END as club_id,
    COUNT(*) as losses
  FROM matchups
  GROUP BY CASE WHEN winner_id = club_a_id THEN club_b_id ELSE club_a_id END
),
combined AS (
  SELECT
    c.id,
    COALESCE(w.wins, 0) as wins,
    COALESCE(w.wins, 0) + COALESCE(l.losses, 0) as total_votes
  FROM clubs c
  LEFT JOIN win_counts w ON c.id = w.club_id
  LEFT JOIN loss_counts l ON c.id = l.club_id
)
UPDATE clubs
SET
  wins = combined.wins,
  total_votes = combined.total_votes
FROM combined
WHERE clubs.id = combined.id;

-- Step 2: Calculate ELO based on win rate with vote weighting
-- Clubs with more votes get their ELO closer to their true skill
-- Base ELO = 1500, max deviation = 200
UPDATE clubs
SET elo_rating = CASE
  WHEN total_votes = 0 THEN 1500
  WHEN total_votes < 10 THEN 1500  -- Not enough data
  ELSE 1500 + ROUND(
    200 * (
      (wins::float / NULLIF(total_votes, 0)) - 0.5
    ) * 2 * LEAST(1.0, total_votes / 500.0)  -- Scale by confidence
  )
END;

-- Make sure no ELO goes below 1300 or above 1700
UPDATE clubs SET elo_rating = 1300 WHERE elo_rating < 1300;
UPDATE clubs SET elo_rating = 1700 WHERE elo_rating > 1700;
