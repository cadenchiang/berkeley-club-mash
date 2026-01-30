-- CLEANUP BOT VOTES: AI Entrepreneurs at Berkeley and Blockchain at Berkeley
--
-- Bot patterns detected:
-- 1. AI Entrepreneurs: fp_worker* fingerprints + 550e8400-e29b-41d4-a716-446655* sessions
--    - ~5000 fake votes from 100 fake workers
-- 2. Blockchain: Single-use sessions creating new session per vote
--    - ~756 fake votes
--
-- Access method: Bots called record_vote RPC directly via public Supabase API

-- Club IDs
-- AI Entrepreneurs at Berkeley: c3221797-d476-459b-8885-ce10be328f05
-- Blockchain at Berkeley: 45b6bc20-aa8b-4100-ac9e-d20140c2ab97

-- Step 1: Delete AI Entrepreneurs bot votes (fp_worker pattern)
DELETE FROM matchups
WHERE fingerprint LIKE 'fp_worker%'
AND winner_id = 'c3221797-d476-459b-8885-ce10be328f05';

-- Step 2: Delete AI Entrepreneurs bot votes (hardcoded session pattern)
DELETE FROM matchups
WHERE session_id LIKE '550e8400-e29b-41d4-a716-446655%'
AND winner_id = 'c3221797-d476-459b-8885-ce10be328f05';

-- Step 3: Delete Blockchain bot votes (single-use sessions)
-- First, find sessions that only voted once AND that vote was for Blockchain
DELETE FROM matchups
WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
AND session_id IN (
  SELECT session_id
  FROM matchups
  GROUP BY session_id
  HAVING COUNT(*) = 1
);

-- Step 4: Also delete any fp_worker votes for Blockchain
DELETE FROM matchups
WHERE fingerprint LIKE 'fp_worker%'
AND winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Step 5: Recalculate AI Entrepreneurs stats
UPDATE clubs SET
  wins = (SELECT COUNT(*) FROM matchups WHERE winner_id = 'c3221797-d476-459b-8885-ce10be328f05'),
  total_votes = (SELECT COUNT(*) FROM matchups WHERE
    (club_a_id = 'c3221797-d476-459b-8885-ce10be328f05' OR club_b_id = 'c3221797-d476-459b-8885-ce10be328f05')
    AND winner_id IS NOT NULL)
WHERE id = 'c3221797-d476-459b-8885-ce10be328f05';

-- Step 6: Recalculate Blockchain stats
UPDATE clubs SET
  wins = (SELECT COUNT(*) FROM matchups WHERE winner_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'),
  total_votes = (SELECT COUNT(*) FROM matchups WHERE
    (club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97' OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97')
    AND winner_id IS NOT NULL)
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Step 7: Reset both clubs to neutral ELO (1500) since their vote history is now compromised
-- They will naturally rise/fall based on legitimate votes going forward
UPDATE clubs SET elo_rating = 1500
WHERE id IN (
  'c3221797-d476-459b-8885-ce10be328f05',
  '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
);

-- Step 8: Ban the bot fingerprint patterns to prevent future abuse
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at)
SELECT DISTINCT session_id, fingerprint, 'Bot activity: fp_worker pattern', NULL::TIMESTAMPTZ
FROM matchups
WHERE fingerprint LIKE 'fp_worker%'
ON CONFLICT DO NOTHING;

-- Step 9: Ban all hardcoded session IDs used by bots
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at)
SELECT DISTINCT session_id, NULL, 'Bot activity: hardcoded session pattern', NULL::TIMESTAMPTZ
FROM matchups
WHERE session_id LIKE '550e8400-e29b-41d4-a716-446655%'
ON CONFLICT DO NOTHING;

-- Log the cleanup for audit purposes
DO $$
DECLARE
  ai_deleted INTEGER;
  bc_deleted INTEGER;
BEGIN
  -- Count would require separate queries; this is just for documentation
  RAISE NOTICE 'Bot cleanup completed for AI Entrepreneurs and Blockchain at Berkeley';
  RAISE NOTICE 'Both clubs reset to ELO 1500';
END $$;
