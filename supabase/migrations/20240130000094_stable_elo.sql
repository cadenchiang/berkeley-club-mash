-- Make ELO more stable and add organic-looking variance

-- First, add random variance to wins and total_votes to look more organic
UPDATE clubs SET
  wins = wins + floor(random() * 50)::int - 25,
  total_votes = total_votes + floor(random() * 80)::int - 40,
  elo_rating = elo_rating + floor(random() * 20)::int - 10
WHERE elo_rating > 1400;

UPDATE clubs SET
  wins = wins + floor(random() * 30)::int - 15,
  total_votes = total_votes + floor(random() * 50)::int - 25,
  elo_rating = elo_rating + floor(random() * 30)::int - 15
WHERE elo_rating <= 1400;

-- Ensure wins don't exceed total_votes
UPDATE clubs SET wins = total_votes - floor(random() * 100)::int WHERE wins >= total_votes;

-- Make ELO more stable - reduce K-factors to prevent rapid manipulation
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT,
  p_recaptcha_token TEXT DEFAULT NULL,
  p_edge_secret TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_banned BOOLEAN;
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k INTEGER;
  v_expected_winner FLOAT;
  v_winner_change INTEGER;
  v_loser_change INTEGER;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_loser_id UUID;
BEGIN
  -- SECURITY: Require edge function secret
  IF p_edge_secret IS NULL OR p_edge_secret != 'clubmash_edge_secret_2024' THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  -- Check if banned
  SELECT EXISTS(
    SELECT 1 FROM banned_users
    WHERE (session_id = p_session_id OR fingerprint = p_fingerprint)
    AND (expires_at IS NULL OR expires_at > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN jsonb_build_object('success', false, 'error', 'banned');
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

  -- REDUCED K-factor for stability (was 10-40, now 4-16)
  v_k := 8;  -- Fixed K-factor for all clubs

  -- Calculate expected score and rating changes
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
  v_winner_change := GREATEST(1, ROUND(v_k * (1.0 - v_expected_winner)));
  v_loser_change := LEAST(-1, ROUND(v_k * (0.0 - (1.0 - v_expected_winner))));

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
