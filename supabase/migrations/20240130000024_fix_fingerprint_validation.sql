-- FIX FINGERPRINT VALIDATION: Real fingerprints are fp_ + 5-7 chars (8-10 total)
-- We were blocking legitimate users with the < 10 char check

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
  v_global_votes_minute INTEGER;
  v_session_total_votes INTEGER;
  v_is_banned BOOLEAN;
  v_unique_fps_for_winner INTEGER;
BEGIN
  -- VALIDATE SESSION ID FORMAT: Must be UUID-like (36 chars with dashes)
  -- Block fake patterns like "session_0", "session_1", etc.
  IF p_session_id ~ '^session_[0-9]+$' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- Session must be valid UUID format (36 chars: 8-4-4-4-12 with dashes)
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- VALIDATE FINGERPRINT: Must start with fp_ if provided
  IF p_fingerprint IS NOT NULL AND NOT (p_fingerprint ~ '^fp_[a-z0-9]+$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_fingerprint',
      'message', 'Invalid fingerprint format.'
    );
  END IF;

  -- Check if user is banned
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

  -- GLOBAL RATE LIMIT: Max 30 votes total per minute
  SELECT COUNT(*) INTO v_global_votes_minute
  FROM matchups
  WHERE created_at > NOW() - INTERVAL '1 minute';

  IF v_global_votes_minute >= 30 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'global_limit',
      'message', 'Too much activity. Please try again in a moment.'
    );
  END IF;

  -- NEW SESSION CHECK: If this is a brand new session, limit to 1 vote per 5 seconds
  SELECT COUNT(*) INTO v_session_total_votes
  FROM matchups
  WHERE session_id = p_session_id;

  -- If new session (0 previous votes), check if there was a vote in last 5 seconds from ANY new session
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

  -- BOT DETECTION: If many unique fingerprints voted for same club in last 10 minutes, suspicious
  IF p_winner_id IS NOT NULL THEN
    SELECT COUNT(DISTINCT fingerprint) INTO v_unique_fps_for_winner
    FROM matchups
    WHERE winner_id = p_winner_id
      AND created_at > NOW() - INTERVAL '10 minutes'
      AND fingerprint IS NOT NULL;

    -- If more than 15 unique fingerprints voted for this club in 10 min, block
    IF v_unique_fps_for_winner >= 15 THEN
      RETURN json_build_object(
        'success', false,
        'error', 'suspicious_activity',
        'message', 'Unusual voting pattern detected. Please try again later.'
      );
    END IF;
  END IF;

  -- 200 votes per session per hour
  SELECT COUNT(*) INTO v_recent_votes_session
  FROM matchups
  WHERE session_id = p_session_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_recent_votes_session >= 200 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'rate_limit_exceeded',
      'message', 'Too many votes. Please try again later.'
    );
  END IF;

  -- 250 votes per fingerprint per hour
  IF p_fingerprint IS NOT NULL AND p_fingerprint != '' THEN
    SELECT COUNT(*) INTO v_recent_votes_fingerprint
    FROM matchups
    WHERE fingerprint = p_fingerprint
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_recent_votes_fingerprint >= 250 THEN
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

  -- Validate winner is one of the two clubs
  IF p_winner_id != p_club_a_id AND p_winner_id != p_club_b_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_winner',
      'message', 'Winner must be one of the two clubs.'
    );
  END IF;

  -- Determine loser
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  -- Get current ratings with row lock
  SELECT elo_rating INTO v_winner_rating FROM clubs WHERE id = p_winner_id FOR UPDATE;
  SELECT elo_rating INTO v_loser_rating FROM clubs WHERE id = v_loser_id FOR UPDATE;

  -- Calculate expected scores (ELO formula)
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating) / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_rating - v_loser_rating) / 400.0));

  -- Calculate new ratings
  v_new_winner_rating := ROUND(v_winner_rating + v_k_factor * (1.0 - v_expected_winner));
  v_new_loser_rating := ROUND(v_loser_rating + v_k_factor * (0.0 - v_expected_loser));

  -- Enforce rating bounds (100-3000)
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
