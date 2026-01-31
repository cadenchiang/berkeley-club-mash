-- Lower K-factor from 32 to 4 for more stable rankings
-- This makes each vote 8x less impactful

CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL,
  p_edge_secret TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_loser_id UUID;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_k_factor INTEGER := 4;  -- Changed from 32 to 4
BEGIN
  -- Verify edge secret
  IF p_edge_secret IS NULL OR p_edge_secret != 'clubmash_edge_secret_2024' THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  -- Determine loser
  IF p_winner_id = p_club_a_id THEN
    v_loser_id := p_club_b_id;
  ELSE
    v_loser_id := p_club_a_id;
  END IF;

  -- Get current ratings
  SELECT elo_rating INTO v_winner_rating FROM clubs WHERE id = p_winner_id;
  SELECT elo_rating INTO v_loser_rating FROM clubs WHERE id = v_loser_id;

  -- Calculate expected scores
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::FLOAT / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_rating - v_loser_rating)::FLOAT / 400.0));

  -- Calculate new ratings
  v_new_winner_rating := ROUND(v_winner_rating + v_k_factor * (1.0 - v_expected_winner));
  v_new_loser_rating := ROUND(v_loser_rating + v_k_factor * (0.0 - v_expected_loser));

  -- Enforce minimum rating of 100
  v_new_loser_rating := GREATEST(v_new_loser_rating, 100);

  -- Update ratings
  UPDATE clubs SET elo_rating = v_new_winner_rating WHERE id = p_winner_id;
  UPDATE clubs SET elo_rating = v_new_loser_rating WHERE id = v_loser_id;

  -- Record the matchup
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id);

  RETURN jsonb_build_object(
    'success', true,
    'winner_new_rating', v_new_winner_rating,
    'loser_new_rating', v_new_loser_rating
  );
END;
$$;
