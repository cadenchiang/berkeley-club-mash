-- FULL DATABASE RESET: Someone vandalized all club data
-- Resetting ALL clubs to starting values

-- Reset every single club to fair starting values
UPDATE clubs SET
  elo_rating = 1500,
  wins = 0,
  total_votes = 0;

-- Also clear all matchup history to start fresh
-- (optional - comment out if you want to keep history)
-- TRUNCATE TABLE matchups;

-- Clear vote cooldowns
DELETE FROM vote_cooldowns;

-- Add RLS policies to prevent direct club updates (extra protection)
-- Only allow updates through the record_vote function

-- Revoke direct update on clubs table from anon users
REVOKE UPDATE ON clubs FROM anon;
REVOKE INSERT ON clubs FROM anon;
REVOKE DELETE ON clubs FROM anon;

-- Only allow SELECT on clubs
GRANT SELECT ON clubs TO anon;

-- Make sure the record_vote function can still update (it runs as SECURITY DEFINER)
-- This means the function runs with the permissions of the function owner (postgres)
-- not the caller, so it can still update clubs
