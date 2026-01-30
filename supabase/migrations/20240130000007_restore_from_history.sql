-- RESTORE FROM HISTORY: Recalculate all stats from matchup history
-- This rebuilds wins and total_votes from actual vote data

-- Step 1: Reset all clubs to base values first
UPDATE clubs SET
  elo_rating = 1500,
  wins = 0,
  total_votes = 0;

-- Step 2: Calculate wins for each club from matchup history
-- (count how many times each club was the winner)
UPDATE clubs c SET
  wins = COALESCE((
    SELECT COUNT(*)
    FROM matchups m
    WHERE m.winner_id = c.id
  ), 0);

-- Step 3: Calculate total_votes (times the club appeared in a matchup with a winner)
UPDATE clubs c SET
  total_votes = COALESCE((
    SELECT COUNT(*)
    FROM matchups m
    WHERE (m.club_a_id = c.id OR m.club_b_id = c.id)
      AND m.winner_id IS NOT NULL
  ), 0);

-- Step 4: Recalculate ELO based on win rate
-- Simple formula: 1500 + (win_rate - 0.5) * 400
-- This gives reasonable ELO spread based on actual performance
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 10 THEN 1500  -- Not enough data
    ELSE LEAST(2500, GREATEST(1000,
      ROUND(1500 + ((wins::float / total_votes) - 0.5) * 800)
    ))
  END;

-- MAXIMUM SECURITY: Lock down the database completely

-- 1. Revoke ALL permissions from anon on clubs
REVOKE ALL ON clubs FROM anon;
GRANT SELECT ON clubs TO anon;

-- 2. Revoke direct access to matchups table (only through function)
REVOKE INSERT, UPDATE, DELETE ON matchups FROM anon;
GRANT SELECT ON matchups TO anon;

-- 3. Revoke access to vote_cooldowns
REVOKE ALL ON vote_cooldowns FROM anon;

-- 4. Create a security barrier view for clubs (optional extra protection)
-- This ensures even SELECT goes through a controlled view

-- 5. Add a check to the record_vote function to validate requests
-- The function already runs as SECURITY DEFINER so it can still update
