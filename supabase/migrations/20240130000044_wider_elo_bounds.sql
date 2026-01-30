-- WIDER ELO BOUNDS: 1000-2000 instead of 1200-1800

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
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner FLOAT;
  v_k_loser FLOAT;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_recent_votes_session INTEGER;
  v_recent_votes_fingerprint INTEGER;
  v_session_total_votes INTEGER;
  v_is_banned BOOLEAN;
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

  -- Get current ratings and vote counts
  SELECT elo_rating, total_votes INTO v_winner_old_rating, v_winner_total FROM clubs WHERE id = p_winner_id;
  SELECT elo_rating, total_votes INTO v_loser_old_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

  -- CHESS ELO CALCULATION
  -- Dynamic K-factor: starts at 40 for new clubs, decreases to 16 minimum
  v_k_winner := GREATEST(16.0, 40.0 / (1.0 + v_winner_total::float / 50.0));
  v_k_loser := GREATEST(16.0, 40.0 / (1.0 + v_loser_total::float / 50.0));

  -- Expected score using standard ELO formula
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_old_rating - v_winner_old_rating)::float / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_old_rating - v_loser_old_rating)::float / 400.0));

  -- New ratings
  v_winner_new_rating := ROUND(v_winner_old_rating + v_k_winner * (1.0 - v_expected_winner));
  v_loser_new_rating := ROUND(v_loser_old_rating + v_k_loser * (0.0 - v_expected_loser));

  -- WIDER BOUNDS: 1000-2000
  v_winner_new_rating := GREATEST(1000, LEAST(2000, v_winner_new_rating));
  v_loser_new_rating := GREATEST(1000, LEAST(2000, v_loser_new_rating));

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
    'loser_change', v_loser_new_rating - v_loser_old_rating
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RECALCULATE ALL ELOS WITH WIDER BOUNDS
CREATE OR REPLACE FUNCTION recalculate_all_elos()
RETURNS void AS $$
DECLARE
  matchup RECORD;
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner FLOAT;
  v_k_loser FLOAT;
  v_expected_winner FLOAT;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_loser_id UUID;
  v_matchup_count INTEGER := 0;
BEGIN
  -- Reset all ratings and vote counts
  UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

  -- Replay all matchups in chronological order
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id, created_at
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_matchup_count := v_matchup_count + 1;

    -- Determine loser
    v_loser_id := CASE WHEN matchup.winner_id = matchup.club_a_id THEN matchup.club_b_id ELSE matchup.club_a_id END;

    -- Get current ratings and counts
    SELECT elo_rating, total_votes INTO v_winner_rating, v_winner_total FROM clubs WHERE id = matchup.winner_id;
    SELECT elo_rating, total_votes INTO v_loser_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

    -- Dynamic K-factor
    v_k_winner := GREATEST(16.0, 40.0 / (1.0 + v_winner_total::float / 50.0));
    v_k_loser := GREATEST(16.0, 40.0 / (1.0 + v_loser_total::float / 50.0));

    -- Expected score
    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));

    -- New ratings
    v_new_winner_rating := ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner));
    v_new_loser_rating := ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner)));

    -- WIDER BOUNDS: 1000-2000
    v_new_winner_rating := GREATEST(1000, LEAST(2000, v_new_winner_rating));
    v_new_loser_rating := GREATEST(1000, LEAST(2000, v_new_loser_rating));

    -- Update winner
    UPDATE clubs SET
      elo_rating = v_new_winner_rating,
      total_votes = total_votes + 1,
      wins = wins + 1
    WHERE id = matchup.winner_id;

    -- Update loser
    UPDATE clubs SET
      elo_rating = v_new_loser_rating,
      total_votes = total_votes + 1
    WHERE id = v_loser_id;
  END LOOP;

  RAISE NOTICE 'Recalculated ELO for % matchups with bounds 1000-2000', v_matchup_count;
END;
$$ LANGUAGE plpgsql;

-- Run the recalculation
SELECT recalculate_all_elos();

-- Drop the temporary function
DROP FUNCTION recalculate_all_elos();
