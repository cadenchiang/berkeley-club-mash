-- MANUAL FIX: Set botted clubs to reasonable values matching other clubs

-- Delete ALL excess matchups involving Blockchain (keep only first 100)
DELETE FROM matchups
WHERE id IN (
  SELECT id FROM matchups
  WHERE (club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
      OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
      OR winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97')
  ORDER BY created_at DESC
  OFFSET 80  -- Keep only oldest 80 matchups
);

-- Delete excess matchups involving Mobile Developers
DELETE FROM matchups
WHERE id IN (
  SELECT id FROM matchups
  WHERE (club_a_id = '45cadb5b-26f0-479c-a991-954bc56df93c'
      OR club_b_id = '45cadb5b-26f0-479c-a991-954bc56df93c'
      OR winner_id = '45cadb5b-26f0-479c-a991-954bc56df93c')
  ORDER BY created_at DESC
  OFFSET 80
);

-- Reset and recalculate ALL clubs from cleaned data
UPDATE clubs SET
  elo_rating = 1500,
  wins = 0,
  total_votes = 0;

-- Recalculate wins
UPDATE clubs c SET
  wins = COALESCE((
    SELECT COUNT(*) FROM matchups m WHERE m.winner_id = c.id
  ), 0);

-- Recalculate total_votes
UPDATE clubs c SET
  total_votes = COALESCE((
    SELECT COUNT(*) FROM matchups m
    WHERE (m.club_a_id = c.id OR m.club_b_id = c.id)
      AND m.winner_id IS NOT NULL
  ), 0);

-- Recalculate ELO
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500
    ELSE LEAST(2000, GREATEST(1100,
      ROUND(1500 + ((wins::float / total_votes) - 0.5) * 500)
    ))
  END;
