-- Delete botted Blockchain matchups and recalculate all stats

-- Step 1: Delete ALL Blockchain matchups (they were botted)
DELETE FROM matchups
WHERE club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
   OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Step 2: Recalculate wins and total_votes from remaining matchups
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

-- Step 3: Calculate ELO based on win rate with vote weighting
UPDATE clubs
SET elo_rating = CASE
  WHEN total_votes = 0 THEN 1500
  WHEN total_votes < 10 THEN 1500
  ELSE 1500 + ROUND(
    200 * (
      (wins::float / NULLIF(total_votes, 0)) - 0.5
    ) * 2 * LEAST(1.0, total_votes / 500.0)
  )
END;

-- Step 4: Clamp ELO to reasonable range
UPDATE clubs SET elo_rating = 1300 WHERE elo_rating < 1300;
UPDATE clubs SET elo_rating = 1700 WHERE elo_rating > 1700;
