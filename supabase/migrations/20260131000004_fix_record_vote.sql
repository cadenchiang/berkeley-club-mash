-- Fix record_vote function - remove updated_at reference

CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL,
  p_edge_secret TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_loser_id UUID;
  v_winner_elo INTEGER;
  v_loser_elo INTEGER;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_k_factor INTEGER := 24;
  v_winner_new_elo INTEGER;
  v_loser_new_elo INTEGER;
  v_matchup_id UUID;
BEGIN
  -- Verify edge secret (rotated 2026-01-31)
  IF p_edge_secret IS NULL OR p_edge_secret != '3eQp1PxTiWdLH6E1qZqgP0NHlE7atSI9' THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  IF p_club_a_id IS NULL OR p_club_b_id IS NULL OR p_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_params');
  END IF;

  IF p_winner_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  IF p_winner_id = p_club_a_id THEN
    v_loser_id := p_club_b_id;
  ELSE
    v_loser_id := p_club_a_id;
  END IF;

  SELECT elo_rating INTO v_winner_elo FROM clubs WHERE id = p_winner_id FOR UPDATE;
  SELECT elo_rating INTO v_loser_elo FROM clubs WHERE id = v_loser_id FOR UPDATE;

  IF v_winner_elo IS NULL OR v_loser_elo IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'club_not_found');
  END IF;

  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_elo - v_winner_elo)::FLOAT / 400.0));
  v_expected_loser := 1.0 - v_expected_winner;

  v_winner_new_elo := GREATEST(100, LEAST(3000, ROUND(v_winner_elo + v_k_factor * (1.0 - v_expected_winner))));
  v_loser_new_elo := GREATEST(100, LEAST(3000, ROUND(v_loser_elo + v_k_factor * (0.0 - v_expected_loser))));

  UPDATE clubs SET 
    elo_rating = v_winner_new_elo,
    wins = wins + 1
  WHERE id = p_winner_id;

  UPDATE clubs SET 
    elo_rating = v_loser_new_elo,
    losses = losses + 1
  WHERE id = v_loser_id;

  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint)
  RETURNING id INTO v_matchup_id;

  RETURN jsonb_build_object(
    'success', true,
    'matchup_id', v_matchup_id,
    'winner_elo_change', v_winner_new_elo - v_winner_elo,
    'loser_elo_change', v_loser_new_elo - v_loser_elo
  );
END;
$$;
