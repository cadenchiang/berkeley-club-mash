-- Secure voting system with server-side ELO calculation
-- Prevents client-side manipulation and race conditions

-- Drop existing function if exists
DROP FUNCTION IF EXISTS record_vote(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS get_random_pair();

-- Constants for ELO calculation
-- K-factor of 32 is standard for chess (USCF uses 32 for players under 2100)
-- Using 400 as the scaling factor (standard chess)

/**
 * Record a vote and update ELO ratings atomically.
 * Uses standard chess ELO formula:
 * Expected Score: E = 1 / (1 + 10^((Rb - Ra) / 400))
 * New Rating: R' = R + K * (S - E) where S=1 for win, S=0 for loss
 *
 * @param p_club_a_id UUID of first club shown
 * @param p_club_b_id UUID of second club shown
 * @param p_winner_id UUID of winning club (NULL for skip)
 * @param p_session_id Session identifier for rate limiting
 * @returns JSON with success status and new ratings
 */
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT
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
  v_recent_votes INTEGER;
BEGIN
  -- Rate limiting: max 1000 votes per session per hour
  SELECT COUNT(*) INTO v_recent_votes
  FROM matchups
  WHERE session_id = p_session_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_recent_votes >= 1000 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'rate_limit_exceeded',
      'message', 'Too many votes. Please try again later.'
    );
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
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id);

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

  -- Get current ratings with row lock to prevent race conditions
  SELECT elo_rating INTO v_winner_rating
  FROM clubs WHERE id = p_winner_id FOR UPDATE;

  SELECT elo_rating INTO v_loser_rating
  FROM clubs WHERE id = v_loser_id FOR UPDATE;

  -- Calculate expected scores (standard chess ELO formula)
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating) / 400.0));
  v_expected_loser := 1.0 / (1.0 + POWER(10.0, (v_winner_rating - v_loser_rating) / 400.0));

  -- Calculate new ratings
  -- Winner: R' = R + K * (1 - E)
  -- Loser: R' = R + K * (0 - E)
  v_new_winner_rating := ROUND(v_winner_rating + v_k_factor * (1.0 - v_expected_winner));
  v_new_loser_rating := ROUND(v_loser_rating + v_k_factor * (0.0 - v_expected_loser));

  -- Enforce minimum rating of 100
  v_new_loser_rating := GREATEST(v_new_loser_rating, 100);

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

/**
 * Get a random pair of clubs for voting.
 * Includes total_votes and wins for display.
 */
CREATE OR REPLACE FUNCTION get_random_pair()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  category TEXT,
  image_url TEXT,
  elo_rating INTEGER,
  total_votes INTEGER,
  wins INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.name, c.description, c.category, c.image_url, c.elo_rating, c.total_votes, c.wins
  FROM clubs c
  ORDER BY RANDOM()
  LIMIT 2;
END;
$$ LANGUAGE plpgsql;

-- Create index for rate limiting queries
CREATE INDEX IF NOT EXISTS idx_matchups_session_time
ON matchups(session_id, created_at DESC);

-- Revoke direct update on clubs (only through functions)
-- Note: Keep the existing policy for now but the function handles validation
