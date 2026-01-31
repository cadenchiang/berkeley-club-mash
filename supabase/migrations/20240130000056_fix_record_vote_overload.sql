-- FIX: Remove duplicate record_vote function causing PostgREST overload error
-- Error: "Could not choose the best candidate function between..."

-- Drop both existing functions
DROP FUNCTION IF EXISTS record_vote(uuid, uuid, uuid, text, text);
DROP FUNCTION IF EXISTS record_vote(uuid, uuid, uuid, text, text, text);

-- Create single unified function with optional recaptcha parameter
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT,
  p_recaptcha_token TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_votes INTEGER;
  v_fingerprint_votes INTEGER;
  v_similar_fp_count INTEGER;
  v_is_banned BOOLEAN;
  v_needs_captcha BOOLEAN := FALSE;
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner INTEGER;
  v_k_loser INTEGER;
  v_expected_winner FLOAT;
  v_winner_change INTEGER;
  v_loser_change INTEGER;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_loser_id UUID;
BEGIN
  -- Check if banned
  SELECT EXISTS(
    SELECT 1 FROM banned_users
    WHERE (session_id = p_session_id OR fingerprint = p_fingerprint)
    AND (expires_at IS NULL OR expires_at > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN jsonb_build_object('success', false, 'error', 'banned');
  END IF;

  -- Validate fingerprint format (fp_ + 1-8 alphanumeric chars)
  IF p_fingerprint IS NOT NULL AND p_fingerprint !~ '^fp_[a-z0-9]{1,8}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_fingerprint');
  END IF;

  -- Check session rate limit (100 votes per session)
  SELECT COUNT(*) INTO v_session_votes
  FROM matchups
  WHERE session_id = p_session_id;

  IF v_session_votes >= 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'rate_limit_exceeded');
  END IF;

  -- Check fingerprint rate limit (50 votes per fingerprint)
  IF p_fingerprint IS NOT NULL THEN
    SELECT COUNT(*) INTO v_fingerprint_votes
    FROM matchups
    WHERE fingerprint = p_fingerprint;

    IF v_fingerprint_votes >= 50 THEN
      RETURN jsonb_build_object('success', false, 'error', 'rate_limit_exceeded');
    END IF;
  END IF;

  -- Skip vote (no winner)
  IF p_winner_id IS NULL THEN
    INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint)
    VALUES (p_club_a_id, p_club_b_id, NULL, p_session_id, p_fingerprint);
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  -- Calculate ELO changes
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  SELECT elo_rating, total_votes INTO v_winner_rating, v_winner_total
  FROM clubs WHERE id = p_winner_id;

  SELECT elo_rating, total_votes INTO v_loser_rating, v_loser_total
  FROM clubs WHERE id = v_loser_id;

  -- FIDE K-factor
  IF v_winner_total < 30 THEN v_k_winner := 40;
  ELSIF v_winner_rating >= 1800 AND v_winner_total >= 200 THEN v_k_winner := 10;
  ELSE v_k_winner := 20;
  END IF;

  IF v_loser_total < 30 THEN v_k_loser := 40;
  ELSIF v_loser_rating >= 1800 AND v_loser_total >= 200 THEN v_k_loser := 10;
  ELSE v_k_loser := 20;
  END IF;

  -- Calculate expected score and rating changes
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
  v_winner_change := ROUND(v_k_winner * (1.0 - v_expected_winner));
  v_loser_change := ROUND(v_k_loser * (0.0 - (1.0 - v_expected_winner)));

  v_new_winner_rating := GREATEST(100, v_winner_rating + v_winner_change);
  v_new_loser_rating := GREATEST(100, v_loser_rating + v_loser_change);

  -- Record the matchup
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint);

  -- Update club ratings
  UPDATE clubs SET
    elo_rating = v_new_winner_rating,
    total_votes = total_votes + 1,
    wins = wins + 1
  WHERE id = p_winner_id;

  UPDATE clubs SET
    elo_rating = v_new_loser_rating,
    total_votes = total_votes + 1
  WHERE id = v_loser_id;

  RETURN jsonb_build_object(
    'success', true,
    'winner_change', v_winner_change,
    'loser_change', v_loser_change,
    'new_winner_rating', v_new_winner_rating,
    'new_loser_rating', v_new_loser_rating
  );
END;
$$;
