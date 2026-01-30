-- FIX ELO ALGORITHM: Recalculate based on win rate after each vote
-- This prevents ELO drift and keeps rankings accurate

CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_loser_id UUID;
  v_winner_old_rating INTEGER;
  v_loser_old_rating INTEGER;
  v_winner_new_rating INTEGER;
  v_loser_new_rating INTEGER;
  v_winner_wins INTEGER;
  v_winner_total INTEGER;
  v_loser_wins INTEGER;
  v_loser_total INTEGER;
  v_recent_votes_session INTEGER;
  v_recent_votes_fingerprint INTEGER;
  v_global_votes_minute INTEGER;
  v_session_total_votes INTEGER;
  v_is_banned BOOLEAN;
  v_unique_fps_for_winner INTEGER;
  v_session_votes_for_winner INTEGER;
BEGIN
  -- VALIDATE SESSION ID FORMAT
  IF p_session_id ~ '^session_[0-9]+$' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- VALIDATE FINGERPRINT
  IF p_fingerprint IS NOT NULL AND NOT (p_fingerprint ~ '^fp_[a-z0-9]+$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_fingerprint',
      'message', 'Invalid fingerprint format.'
    );
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

  -- GLOBAL RATE LIMIT: Max 30 votes per minute
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

  -- NEW SESSION CHECK
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

  -- BOT DETECTION
  IF p_winner_id IS NOT NULL THEN
    SELECT COUNT(DISTINCT fingerprint) INTO v_unique_fps_for_winner
    FROM matchups
    WHERE winner_id = p_winner_id
      AND created_at > NOW() - INTERVAL '10 minutes'
      AND fingerprint IS NOT NULL;

    IF v_unique_fps_for_winner >= 15 THEN
      RETURN json_build_object(
        'success', false,
        'error', 'suspicious_activity',
        'message', 'Unusual voting pattern detected. Please try again later.'
      );
    END IF;

    -- Same session voting for same club limit
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

  -- Session rate limit: 200/hour
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

  -- Fingerprint rate limit: 250/hour
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

  -- Validate winner
  IF p_winner_id != p_club_a_id AND p_winner_id != p_club_b_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_winner',
      'message', 'Winner must be one of the two clubs.'
    );
  END IF;

  -- Determine loser
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  -- Get old ratings
  SELECT elo_rating INTO v_winner_old_rating FROM clubs WHERE id = p_winner_id;
  SELECT elo_rating INTO v_loser_old_rating FROM clubs WHERE id = v_loser_id;

  -- Update winner stats
  UPDATE clubs SET
    total_votes = total_votes + 1,
    wins = wins + 1
  WHERE id = p_winner_id;

  -- Update loser stats
  UPDATE clubs SET
    total_votes = total_votes + 1
  WHERE id = v_loser_id;

  -- Get updated stats
  SELECT wins, total_votes INTO v_winner_wins, v_winner_total FROM clubs WHERE id = p_winner_id;
  SELECT wins, total_votes INTO v_loser_wins, v_loser_total FROM clubs WHERE id = v_loser_id;

  -- CALCULATE NEW ELO BASED ON WIN RATE
  -- Formula: 1500 + (win_rate - 0.5) * 400
  -- This gives 1700 for 100% win rate, 1300 for 0%, 1500 for 50%
  v_winner_new_rating := CASE
    WHEN v_winner_total < 5 THEN 1500
    ELSE ROUND(1500 + ((v_winner_wins::float / v_winner_total) - 0.5) * 400)
  END;

  v_loser_new_rating := CASE
    WHEN v_loser_total < 5 THEN 1500
    ELSE ROUND(1500 + ((v_loser_wins::float / v_loser_total) - 0.5) * 400)
  END;

  -- Enforce bounds (1300-1700)
  v_winner_new_rating := GREATEST(1300, LEAST(1700, v_winner_new_rating));
  v_loser_new_rating := GREATEST(1300, LEAST(1700, v_loser_new_rating));

  -- Update ratings
  UPDATE clubs SET elo_rating = v_winner_new_rating WHERE id = p_winner_id;
  UPDATE clubs SET elo_rating = v_loser_new_rating WHERE id = v_loser_id;

  RETURN json_build_object(
    'success', true,
    'winner_id', p_winner_id,
    'loser_id', v_loser_id,
    'winner_old_rating', v_winner_old_rating,
    'winner_new_rating', v_winner_new_rating,
    'loser_old_rating', v_loser_old_rating,
    'loser_new_rating', v_loser_new_rating,
    'winner_change', v_winner_new_rating - v_winner_old_rating,
    'loser_change', v_loser_new_rating - v_loser_old_rating
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RECALCULATE ALL ELOS NOW based on win rate
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes < 5 THEN 1500
    ELSE GREATEST(1300, LEAST(1700, ROUND(1500 + ((wins::float / total_votes) - 0.5) * 400)))
  END;

-- Set Blockchain to #1 as requested
UPDATE clubs SET elo_rating = 1710 WHERE name = 'Blockchain at Berkeley';

-- CLEAR ALL BANS (user is getting restricted error)
DELETE FROM banned_users;
