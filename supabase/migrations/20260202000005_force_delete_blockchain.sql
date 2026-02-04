-- Force delete Blockchain matchups using a function (to avoid timeout issues)

CREATE OR REPLACE FUNCTION cleanup_blockchain_votes()
RETURNS TEXT AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  -- Delete matchups where Blockchain participated
  DELETE FROM matchups
  WHERE club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
     OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Reset Blockchain's stats
  UPDATE clubs
  SET elo_rating = 1500, wins = 0, total_votes = 0
  WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

  RETURN 'Deleted ' || v_deleted || ' matchups';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the cleanup
SELECT cleanup_blockchain_votes();

-- Now recalculate all other clubs
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

-- Recalculate ELO
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

UPDATE clubs SET elo_rating = 1300 WHERE elo_rating < 1300;
UPDATE clubs SET elo_rating = 1700 WHERE elo_rating > 1700;

-- Cleanup
DROP FUNCTION cleanup_blockchain_votes();
