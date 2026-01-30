-- SECURITY HARDENING: reCAPTCHA support, better fingerprint validation, cleanup suspicious votes

-- Step 1: Clean up remaining suspicious votes
-- Delete fp_abc123xyz (clearly fake test fingerprint)
DELETE FROM matchups WHERE fingerprint = 'fp_abc123xyz';

-- Delete any fingerprint that's too long (legit fingerprints are fp_ + ~6-7 base36 chars)
-- Legit: fp_1a2b3c (max 7 chars after fp_)
-- Suspicious: fp_abc123xyz (9 chars - too long for a 32-bit hash in base36)
DELETE FROM matchups WHERE fingerprint IS NOT NULL AND LENGTH(fingerprint) > 12;

-- Delete any remaining single-use sessions that voted for AI Entrepreneurs with high frequency
-- This catches bot patterns we may have missed
DELETE FROM matchups
WHERE winner_id = 'c3221797-d476-459b-8885-ce10be328f05'
AND session_id IN (
  SELECT session_id
  FROM matchups
  WHERE winner_id = 'c3221797-d476-459b-8885-ce10be328f05'
  GROUP BY session_id
  HAVING COUNT(*) = 1
)
AND created_at > NOW() - INTERVAL '24 hours';

-- Step 2: Create table to track reCAPTCHA challenges
CREATE TABLE IF NOT EXISTS recaptcha_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT NOT NULL,
  fingerprint TEXT,
  challenge_token TEXT,
  passed BOOLEAN DEFAULT FALSE,
  votes_since_challenge INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '1 hour'
);

CREATE INDEX IF NOT EXISTS idx_recaptcha_session ON recaptcha_challenges(session_id, created_at DESC);

-- Step 3: Create improved record_vote function with all security measures
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL,
  p_recaptcha_token TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_loser_id UUID;
  v_winner_old_rating INTEGER;
  v_loser_old_rating INTEGER;
  v_winner_new_rating INTEGER;
  v_loser_new_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner INTEGER;
  v_k_loser INTEGER;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_recent_votes_session INTEGER;
  v_recent_votes_fingerprint INTEGER;
  v_session_total_votes INTEGER;
  v_is_banned BOOLEAN;
  v_session_votes_for_winner INTEGER;
  v_fingerprint_prefix TEXT;
  v_similar_fingerprints INTEGER;
  v_needs_captcha BOOLEAN := FALSE;
  v_votes_since_captcha INTEGER;
BEGIN
  -- ============================================
  -- VALIDATION PHASE
  -- ============================================

  -- VALIDATE SESSION ID FORMAT (must be proper UUID)
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- Block known bot session patterns
  IF p_session_id LIKE '550e8400-e29b-41d4-a716-446655%' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'banned',
      'message', 'Access restricted.'
    );
  END IF;

  -- VALIDATE FINGERPRINT FORMAT
  IF p_fingerprint IS NOT NULL THEN
    -- Block fp_worker pattern (known bot)
    IF p_fingerprint ~ '^fp_worker' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'banned',
        'message', 'Access restricted.'
      );
    END IF;

    -- Block obviously fake fingerprints (like fp_abc123xyz)
    IF p_fingerprint IN ('fp_abc123xyz', 'fp_test', 'fp_fake', 'fp_bot') THEN
      RETURN json_build_object(
        'success', false,
        'error', 'banned',
        'message', 'Access restricted.'
      );
    END IF;

    -- Must match expected format: fp_ followed by 1-8 lowercase alphanumeric chars
    -- (32-bit hash in base36 = max 7 chars, allow 8 for safety)
    IF NOT (p_fingerprint ~ '^fp_[a-z0-9]{1,8}$') THEN
      RETURN json_build_object(
        'success', false,
        'error', 'invalid_fingerprint',
        'message', 'Invalid fingerprint format.'
      );
    END IF;

    -- ANTI-SPOOFING: Check for too many similar fingerprints
    -- If someone is generating many fingerprints with similar patterns, block them
    v_fingerprint_prefix := LEFT(p_fingerprint, 6);
    SELECT COUNT(DISTINCT fingerprint) INTO v_similar_fingerprints
    FROM matchups
    WHERE fingerprint LIKE v_fingerprint_prefix || '%'
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_similar_fingerprints > 5 THEN
      RETURN json_build_object(
        'success', false,
        'error', 'suspicious_activity',
        'message', 'Suspicious activity detected. Please try again later.'
      );
    END IF;
  END IF;

  -- Check if banned
  SELECT EXISTS(
    SELECT 1 FROM banned_users
    WHERE (session_id = p_session_id OR fingerprint = p_fingerprint)
      AND (expires_at IS NULL OR expires_at > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN json_build_object(
      'success', false,
      'error', 'banned',
      'message', 'Your access has been restricted.'
    );
  END IF;

  -- ============================================
  -- RATE LIMITING PHASE
  -- ============================================

  -- NEW SESSION CHECK: 1 new session per 5 seconds
  SELECT COUNT(*) INTO v_session_total_votes
  FROM matchups
  WHERE session_id = p_session_id;

  IF v_session_total_votes = 0 THEN
    IF EXISTS (
      SELECT 1 FROM matchups m
      WHERE m.created_at > NOW() - INTERVAL '5 seconds'
      AND NOT EXISTS (
        SELECT 1 FROM matchups m2
        WHERE m2.session_id = m.session_id
        AND m2.created_at < m.created_at
      )
    ) THEN
      RETURN json_build_object(
        'success', false,
        'error', 'new_session_limit',
        'message', 'Please wait a moment before voting.'
      );
    END IF;
  END IF;

  -- Same session voting for same club limit: 10/hour
  IF p_winner_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_session_votes_for_winner
    FROM matchups
    WHERE session_id = p_session_id
      AND winner_id = p_winner_id
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_session_votes_for_winner >= 10 THEN
      RETURN json_build_object(
        'success', false,
        'error', 'same_club_limit',
        'message', 'You have voted for this club too many times. Try voting for other clubs!'
      );
    END IF;
  END IF;

  -- Session rate limit: 100/hour (reduced from 200)
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

  -- Fingerprint rate limit: 150/hour (reduced from 250)
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

  -- ============================================
  -- CAPTCHA CHECK PHASE
  -- ============================================

  -- Check if session needs reCAPTCHA (every 20 votes)
  SELECT COUNT(*) INTO v_votes_since_captcha
  FROM matchups
  WHERE session_id = p_session_id
    AND created_at > COALESCE(
      (SELECT MAX(created_at) FROM recaptcha_challenges
       WHERE session_id = p_session_id AND passed = TRUE),
      '1970-01-01'::TIMESTAMPTZ
    );

  IF v_votes_since_captcha >= 20 THEN
    v_needs_captcha := TRUE;

    -- If no captcha token provided, request one
    IF p_recaptcha_token IS NULL OR p_recaptcha_token = '' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'captcha_required',
        'message', 'Please complete the verification to continue voting.',
        'captcha_required', true
      );
    END IF;

    -- Token provided - record the challenge as passed
    -- (In production, you'd verify the token with Google's API)
    INSERT INTO recaptcha_challenges (session_id, fingerprint, challenge_token, passed)
    VALUES (p_session_id, p_fingerprint, p_recaptcha_token, TRUE);
  END IF;

  -- ============================================
  -- VOTE RECORDING PHASE
  -- ============================================

  -- Validate clubs exist
  IF NOT EXISTS (SELECT 1 FROM clubs WHERE id = p_club_a_id) OR
     NOT EXISTS (SELECT 1 FROM clubs WHERE id = p_club_b_id) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_clubs',
      'message', 'Invalid club IDs provided.'
    );
  END IF;

  -- Record the matchup
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint);

  -- If skipped, just return success
  IF p_winner_id IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'skipped', true
    );
  END IF;

  -- Validate winner
  IF p_winner_id != p_club_a_id AND p_winner_id != p_club_b_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_winner',
      'message', 'Winner must be one of the two clubs.'
    );
  END IF;

  -- ============================================
  -- ELO CALCULATION PHASE
  -- ============================================

  -- Determine loser
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  -- Get current ratings and vote counts
  SELECT elo_rating, total_votes INTO v_winner_old_rating, v_winner_total FROM clubs WHERE id = p_winner_id;
  SELECT elo_rating, total_votes INTO v_loser_old_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

  -- FIDE-style K-factor
  IF v_winner_total < 30 THEN
    v_k_winner := 40;
  ELSIF v_winner_old_rating >= 1800 AND v_winner_total >= 200 THEN
    v_k_winner := 10;
  ELSE
    v_k_winner := 20;
  END IF;

  IF v_loser_total < 30 THEN
    v_k_loser := 40;
  ELSIF v_loser_old_rating >= 1800 AND v_loser_total >= 200 THEN
    v_k_loser := 10;
  ELSE
    v_k_loser := 20;
  END IF;

  -- Expected score
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_old_rating - v_winner_old_rating)::float / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_old_rating - v_loser_old_rating)::float / 400.0));

  -- New ratings (NO UPPER BOUND)
  v_winner_new_rating := ROUND(v_winner_old_rating + v_k_winner * (1.0 - v_expected_winner));
  v_loser_new_rating := ROUND(v_loser_old_rating + v_k_loser * (0.0 - v_expected_loser));

  -- Only enforce minimum of 100
  v_winner_new_rating := GREATEST(100, v_winner_new_rating);
  v_loser_new_rating := GREATEST(100, v_loser_new_rating);

  -- Update winner stats
  UPDATE clubs SET
    elo_rating = v_winner_new_rating,
    total_votes = total_votes + 1,
    wins = wins + 1
  WHERE id = p_winner_id;

  -- Update loser stats
  UPDATE clubs SET
    elo_rating = v_loser_new_rating,
    total_votes = total_votes + 1
  WHERE id = v_loser_id;

  RETURN json_build_object(
    'success', true,
    'winner_id', p_winner_id,
    'loser_id', v_loser_id,
    'winner_old_rating', v_winner_old_rating,
    'winner_new_rating', v_winner_new_rating,
    'loser_old_rating', v_loser_old_rating,
    'loser_new_rating', v_loser_new_rating,
    'winner_change', v_winner_new_rating - v_winner_old_rating,
    'loser_change', v_loser_new_rating - v_loser_old_rating,
    'k_winner', v_k_winner,
    'k_loser', v_k_loser
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create function to get total vote count (replacing today's count)
CREATE OR REPLACE FUNCTION get_total_vote_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM matchups
    WHERE winner_id IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql;

-- Step 5: Recalculate ELOs after cleanup
CREATE OR REPLACE FUNCTION recalculate_all_elos_final()
RETURNS void AS $$
DECLARE
  matchup RECORD;
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner INTEGER;
  v_k_loser INTEGER;
  v_expected_winner FLOAT;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_loser_id UUID;
  v_matchup_count INTEGER := 0;
BEGIN
  -- Reset all ratings and vote counts
  UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

  -- Replay all remaining matchups
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_matchup_count := v_matchup_count + 1;
    v_loser_id := CASE WHEN matchup.winner_id = matchup.club_a_id THEN matchup.club_b_id ELSE matchup.club_a_id END;

    SELECT elo_rating, total_votes INTO v_winner_rating, v_winner_total FROM clubs WHERE id = matchup.winner_id;
    SELECT elo_rating, total_votes INTO v_loser_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

    -- K-factor
    IF v_winner_total < 30 THEN v_k_winner := 40;
    ELSIF v_winner_rating >= 1800 AND v_winner_total >= 200 THEN v_k_winner := 10;
    ELSE v_k_winner := 20;
    END IF;

    IF v_loser_total < 30 THEN v_k_loser := 40;
    ELSIF v_loser_rating >= 1800 AND v_loser_total >= 200 THEN v_k_loser := 10;
    ELSE v_k_loser := 20;
    END IF;

    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
    v_new_winner_rating := GREATEST(100, ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner)));
    v_new_loser_rating := GREATEST(100, ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner))));

    UPDATE clubs SET elo_rating = v_new_winner_rating, total_votes = total_votes + 1, wins = wins + 1 WHERE id = matchup.winner_id;
    UPDATE clubs SET elo_rating = v_new_loser_rating, total_votes = total_votes + 1 WHERE id = v_loser_id;
  END LOOP;

  RAISE NOTICE 'Final recalculation: % matchups', v_matchup_count;
END;
$$ LANGUAGE plpgsql;

SELECT recalculate_all_elos_final();
DROP FUNCTION recalculate_all_elos_final();

-- Step 6: Add RLS for recaptcha_challenges table
ALTER TABLE recaptcha_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Challenges are insertable by service" ON recaptcha_challenges
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Challenges are viewable by service" ON recaptcha_challenges
  FOR SELECT USING (true);
