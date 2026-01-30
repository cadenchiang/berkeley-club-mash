-- Set Blockchain ELO to 1780
UPDATE clubs SET elo_rating = 1780
WHERE name = 'Blockchain at Berkeley';

-- Remove bot votes from Furries (session with 113 votes)
DELETE FROM matchups
WHERE session_id = 'de75bcf9-2757-4ca8-b5b6-3e73a7849271';

-- Recalculate Furries stats from remaining votes
UPDATE clubs SET
  wins = (SELECT COUNT(*) FROM matchups WHERE winner_id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c'),
  total_votes = (SELECT COUNT(*) FROM matchups WHERE
    (club_a_id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c' OR club_b_id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c')
    AND winner_id IS NOT NULL)
WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c';

-- Recalculate Furries ELO
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500
    ELSE LEAST(2000, GREATEST(1100,
      ROUND(1500 + ((wins::float / total_votes) - 0.5) * 500)
    ))
  END
WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c';
