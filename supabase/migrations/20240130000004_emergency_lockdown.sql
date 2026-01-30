-- EMERGENCY LOCKDOWN: Multiple layers of bot protection
-- Prevents direct API abuse by adding club-level and global rate limits

-- 1. Add same-club voting limit: max 5 votes for same club per session per hour
-- 2. Add global club throttle: max 20 votes for any club per minute
-- 3. Add minimum time between votes: 2 seconds
-- 4. Cap ELO rating to prevent overflow

-- Create a table to track vote timestamps for cooldown
CREATE TABLE IF NOT EXISTS vote_cooldowns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT NOT NULL,
  fingerprint TEXT,
  last_vote_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vote_cooldowns_session ON vote_cooldowns(session_id);
CREATE INDEX IF NOT EXISTS idx_vote_cooldowns_fingerprint ON vote_cooldowns(fingerprint);

-- Replace the record_vote function with emergency protections
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_loser_id UUID;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_k_factor INTEGER := 32;
  v_recent_votes_session INTEGER;
  v_recent_votes_fingerprint INTEGER;
  v_same_club_votes INTEGER;
  v_club_recent_wins INTEGER;
  v_last_vote_time TIMESTAMPTZ;
  v_time_since_last INTERVAL;
BEGIN
  -- PROTECTION 1: Minimum 2 second cooldown between votes (per session)
  SELECT last_vote_at INTO v_last_vote_time
  FROM vote_cooldowns
  WHERE session_id = p_session_id
  ORDER BY last_vote_at DESC
  LIMIT 1;

  IF v_last_vote_time IS NOT NULL THEN
    v_time_since_last := NOW() - v_last_vote_time;
    IF v_time_since_last < INTERVAL '2 seconds' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'cooldown',
        'message', 'Please wait before voting again.'
      );
    END IF;
  END IF;

  -- PROTECTION 2: Rate limiting by session: max 100 votes per session per hour
  SELECT COUNT(*) INTO v_recent_votes_session
  FROM matchups
  WHERE session_id = p_session_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_recent_votes_session >= 100 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'rate_limit_exceeded',
      'message', 'Too many votes. Please try again later.'
    );
  END IF;

  -- PROTECTION 3: Rate limiting by fingerprint: max 150 votes per fingerprint per hour
  IF p_fingerprint IS NOT NULL AND p_fingerprint != '' THEN
    SELECT COUNT(*) INTO v_recent_votes_fingerprint
    FROM matchups
    WHERE fingerprint = p_fingerprint
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_recent_votes_fingerprint >= 150 THEN
      RETURN json_build_object(
        'success', false,
        'error', 'rate_limit_exceeded',
        'message', 'Too many votes from this device. Please try again later.'
      );
    END IF;
  END IF;

  -- Validate clubs exist
  IF NOT EXISTS (SELECT 1 FROM clubs WHERE id = p_club_a_id) OR
     NOT EXISTS (SELECT 1 FROM clubs WHERE id = p_club_b_id) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_clubs',
      'message', 'Invalid club IDs provided.'
    );
  END IF;

  -- Update cooldown tracking
  INSERT INTO vote_cooldowns (session_id, fingerprint, last_vote_at)
  VALUES (p_session_id, p_fingerprint, NOW())
  ON CONFLICT DO NOTHING;

  -- Also update if exists
  UPDATE vote_cooldowns
  SET last_vote_at = NOW()
  WHERE session_id = p_session_id;

  -- Record the matchup with fingerprint
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint);

  -- If skipped, just return success
  IF p_winner_id IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'skipped', true
    );
  END IF;

  -- Validate winner is one of the two clubs
  IF p_winner_id != p_club_a_id AND p_winner_id != p_club_b_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_winner',
      'message', 'Winner must be one of the two clubs.'
    );
  END IF;

  -- PROTECTION 4: Same-club voting limit per session (max 3 votes for same club per hour)
  SELECT COUNT(*) INTO v_same_club_votes
  FROM matchups
  WHERE session_id = p_session_id
    AND winner_id = p_winner_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_same_club_votes >= 3 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'same_club_limit',
      'message', 'You have voted for this club too many times. Try voting for other clubs!'
    );
  END IF;

  -- PROTECTION 5: Global club throttle (max 30 wins for any club per minute)
  SELECT COUNT(*) INTO v_club_recent_wins
  FROM matchups
  WHERE winner_id = p_winner_id
    AND created_at > NOW() - INTERVAL '1 minute';

  IF v_club_recent_wins >= 30 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'club_throttle',
      'message', 'This club is receiving too many votes. Please try again in a moment.'
    );
  END IF;

  -- Determine loser
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  -- Get current ratings with row lock to prevent race conditions
  SELECT elo_rating INTO v_winner_rating
  FROM clubs WHERE id = p_winner_id FOR UPDATE;

  SELECT elo_rating INTO v_loser_rating
  FROM clubs WHERE id = v_loser_id FOR UPDATE;

  -- Calculate expected scores (standard chess ELO formula)
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating) / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_rating - v_loser_rating) / 400.0));

  -- Calculate new ratings
  v_new_winner_rating := ROUND(v_winner_rating + v_k_factor * (1.0 - v_expected_winner));
  v_new_loser_rating := ROUND(v_loser_rating + v_k_factor * (0.0 - v_expected_loser));

  -- PROTECTION 6: Enforce minimum rating of 100 and MAXIMUM of 3000 to prevent overflow
  v_new_loser_rating := GREATEST(v_new_loser_rating, 100);
  v_new_winner_rating := LEAST(v_new_winner_rating, 3000);

  -- Update winner
  UPDATE clubs SET
    elo_rating = v_new_winner_rating,
    total_votes = total_votes + 1,
    wins = wins + 1
  WHERE id = p_winner_id;

  -- Update loser
  UPDATE clubs SET
    elo_rating = v_new_loser_rating,
    total_votes = total_votes + 1
  WHERE id = v_loser_id;

  RETURN json_build_object(
    'success', true,
    'winner_id', p_winner_id,
    'loser_id', v_loser_id,
    'winner_old_rating', v_winner_rating,
    'winner_new_rating', v_new_winner_rating,
    'loser_old_rating', v_loser_rating,
    'loser_new_rating', v_new_loser_rating,
    'winner_change', v_new_winner_rating - v_winner_rating,
    'loser_change', v_new_loser_rating - v_loser_rating
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- IMMEDIATE FIX: Reset Blockchain at Berkeley to fair values
UPDATE clubs
SET elo_rating = 1500, wins = 50, total_votes = 100
WHERE name = 'Blockchain at Berkeley';

-- Also reset Mobile Developers of Berkeley
UPDATE clubs
SET elo_rating = 1500, wins = 50, total_votes = 100
WHERE name = 'Mobile Developers of Berkeley';

-- Clean up old cooldown entries periodically (keep last 24 hours)
DELETE FROM vote_cooldowns WHERE created_at < NOW() - INTERVAL '24 hours';
