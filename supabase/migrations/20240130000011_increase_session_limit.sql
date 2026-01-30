-- Increase session rate limit to 200 votes per hour

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
  v_is_banned BOOLEAN;
BEGIN
  -- PROTECTION 0: Check if user is banned
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

  -- PROTECTION 1: Minimum 2 second cooldown between votes
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

  -- PROTECTION 2: Rate limiting by session: max 200 votes per session per hour
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

  -- PROTECTION 3: Rate limiting by fingerprint: max 250 votes per fingerprint per hour
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

  -- Update cooldown tracking
  INSERT INTO vote_cooldowns (session_id, fingerprint, last_vote_at)
  VALUES (p_session_id, p_fingerprint, NOW())
  ON CONFLICT DO NOTHING;

  UPDATE vote_cooldowns
  SET last_vote_at = NOW()
  WHERE session_id = p_session_id;

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

  -- PROTECTION 4: Same-club voting limit (max 3 votes for same club per hour)
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

  -- PROTECTION 5: Global club throttle (max 30 wins per club per minute)
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

  -- Get current ratings with row lock
  SELECT elo_rating INTO v_winner_rating FROM clubs WHERE id = p_winner_id FOR UPDATE;
  SELECT elo_rating INTO v_loser_rating FROM clubs WHERE id = v_loser_id FOR UPDATE;

  -- Calculate expected scores (ELO formula)
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating) / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_rating - v_loser_rating) / 400.0));

  -- Calculate new ratings
  v_new_winner_rating := ROUND(v_winner_rating + v_k_factor * (1.0 - v_expected_winner));
  v_new_loser_rating := ROUND(v_loser_rating + v_k_factor * (0.0 - v_expected_loser));

  -- PROTECTION 6: Enforce rating bounds (100-3000)
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
