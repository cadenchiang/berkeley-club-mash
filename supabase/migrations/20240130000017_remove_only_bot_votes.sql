-- Remove only bot votes (single-use sessions voting for Blockchain)
-- Keep legitimate votes

-- Delete matchups from sessions that:
-- 1. Only voted once total AND
-- 2. That vote was for Blockchain
DELETE FROM matchups
WHERE session_id IN (
  SELECT session_id
  FROM matchups
  GROUP BY session_id
  HAVING COUNT(*) = 1
)
AND winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Recalculate Blockchain stats from remaining votes
UPDATE clubs SET
  wins = (SELECT COUNT(*) FROM matchups WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'),
  total_votes = (SELECT COUNT(*) FROM matchups WHERE
    (club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97' OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97')
    AND winner_id IS NOT NULL)
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Recalculate ELO based on win rate
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500
    ELSE LEAST(2000, GREATEST(1100,
      ROUND(1500 + ((wins::float / total_votes) - 0.5) * 500)
    ))
  END
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
