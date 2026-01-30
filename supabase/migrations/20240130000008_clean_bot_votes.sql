-- CLEAN BOT VOTES: Remove suspicious bot activity and recalculate

-- Bot IDs identified:
-- Blockchain at Berkeley: 45b6bc20-aa8b-4100-ac9e-d20140c2ab97
-- Mobile Developers of Berkeley: 45cadb5b-26f0-479c-a991-954bc56df93c

-- Step 1: Delete bot votes for Blockchain
-- Keep only votes from sessions that voted for them 3 or fewer times
DELETE FROM matchups
WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
AND session_id IN (
  SELECT session_id
  FROM matchups
  WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
  GROUP BY session_id
  HAVING COUNT(*) > 3
);

-- Also delete matchups where Blockchain appeared but from bot sessions
DELETE FROM matchups
WHERE (club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97' OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97')
AND session_id IN (
  SELECT DISTINCT session_id
  FROM matchups
  WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
  GROUP BY session_id
  HAVING COUNT(*) > 5
);

-- Step 2: Delete bot votes for Mobile Developers
DELETE FROM matchups
WHERE winner_id = '45cadb5b-26f0-479c-a991-954bc56df93c'
AND session_id IN (
  SELECT session_id
  FROM matchups
  WHERE winner_id = '45cadb5b-26f0-479c-a991-954bc56df93c'
  GROUP BY session_id
  HAVING COUNT(*) > 3
);

-- Step 3: Reset all clubs to base values
UPDATE clubs SET
  elo_rating = 1500,
  wins = 0,
  total_votes = 0;

-- Step 4: Recalculate wins from cleaned matchup history
UPDATE clubs c SET
  wins = COALESCE((
    SELECT COUNT(*)
    FROM matchups m
    WHERE m.winner_id = c.id
  ), 0);

-- Step 5: Recalculate total_votes from cleaned history
UPDATE clubs c SET
  total_votes = COALESCE((
    SELECT COUNT(*)
    FROM matchups m
    WHERE (m.club_a_id = c.id OR m.club_b_id = c.id)
      AND m.winner_id IS NOT NULL
  ), 0);

-- Step 6: Recalculate ELO based on win rate
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500  -- Not enough data
    ELSE LEAST(2200, GREATEST(1100,
      ROUND(1500 + ((wins::float / total_votes) - 0.5) * 600)
    ))
  END;

-- MAXIMUM SECURITY LOCKDOWN
-- Ensure no direct table access

REVOKE ALL ON clubs FROM anon;
REVOKE ALL ON matchups FROM anon;
REVOKE ALL ON vote_cooldowns FROM anon;

-- Only allow SELECT on clubs and matchups
GRANT SELECT ON clubs TO anon;
GRANT SELECT ON matchups TO anon;

-- The record_vote function runs as SECURITY DEFINER (superuser)
-- so it can still INSERT into matchups and UPDATE clubs
