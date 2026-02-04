-- Fix Blockchain at Berkeley botting and add IP-based rate limiting

-- 1. Reset Blockchain at Berkeley stats
UPDATE clubs
SET elo_rating = 1500, wins = 0, total_votes = 0
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- 2. Delete all Blockchain matchups (they were botted)
DELETE FROM matchups WHERE club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'
                       OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- 3. Add IP address column to matchups for tracking
ALTER TABLE matchups ADD COLUMN IF NOT EXISTS ip_address TEXT;

-- 4. Create index for IP rate limiting
CREATE INDEX IF NOT EXISTS idx_matchups_ip_created ON matchups(ip_address, created_at);

-- 5. Create IP rate limit tracking table
CREATE TABLE IF NOT EXISTS ip_rate_limits (
  ip_address TEXT PRIMARY KEY,
  vote_count INTEGER DEFAULT 0,
  window_start TIMESTAMPTZ DEFAULT NOW(),
  is_banned BOOLEAN DEFAULT FALSE
);

-- 6. Update record_vote function with IP-based rate limiting
CREATE OR REPLACE FUNCTION record_vote(
  p_club_a_id UUID,
  p_club_b_id UUID,
  p_winner_id UUID,
  p_session_id TEXT,
  p_fingerprint TEXT DEFAULT NULL,
  p_edge_secret TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_loser_id UUID;
  v_winner_elo INTEGER;
  v_loser_elo INTEGER;
  v_expected_winner FLOAT;
  v_expected_loser FLOAT;
  v_k_factor INTEGER := 32;
  v_winner_change INTEGER;
  v_loser_change INTEGER;
  v_matchup_id UUID;
  v_ip_record RECORD;
  v_recent_ip_votes INTEGER;
BEGIN
  -- Validate edge secret (only edge function should call this)
  IF p_edge_secret IS NULL OR p_edge_secret != '3eQp1PxTiWdLH6E1qZqgP0NHlE7atSI9' THEN
    RETURN json_build_object('success', false, 'error', 'unauthorized');
  END IF;

  -- IP-based rate limiting (max 100 votes per hour per IP)
  IF p_ip_address IS NOT NULL AND p_ip_address != 'unknown' THEN
    -- Check if IP is banned
    SELECT * INTO v_ip_record FROM ip_rate_limits WHERE ip_address = p_ip_address;

    IF v_ip_record.is_banned THEN
      RETURN json_build_object('success', false, 'error', 'banned', 'message', 'Access denied.');
    END IF;

    -- Count recent votes from this IP
    SELECT COUNT(*) INTO v_recent_ip_votes
    FROM matchups
    WHERE ip_address = p_ip_address
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_recent_ip_votes >= 100 THEN
      -- Auto-ban IPs that hit rate limit
      INSERT INTO ip_rate_limits (ip_address, vote_count, is_banned)
      VALUES (p_ip_address, v_recent_ip_votes, TRUE)
      ON CONFLICT (ip_address) DO UPDATE SET is_banned = TRUE, vote_count = v_recent_ip_votes;

      -- Also add to banned_ips table
      INSERT INTO banned_ips (ip_address, reason)
      VALUES (p_ip_address, 'Auto-banned: exceeded 100 votes/hour')
      ON CONFLICT (ip_address) DO NOTHING;

      RETURN json_build_object('success', false, 'error', 'rate_limit', 'message', 'Too many votes.');
    END IF;

    -- Track vote count
    INSERT INTO ip_rate_limits (ip_address, vote_count, window_start)
    VALUES (p_ip_address, 1, NOW())
    ON CONFLICT (ip_address) DO UPDATE
    SET vote_count = CASE
      WHEN ip_rate_limits.window_start < NOW() - INTERVAL '1 hour'
      THEN 1
      ELSE ip_rate_limits.vote_count + 1
    END,
    window_start = CASE
      WHEN ip_rate_limits.window_start < NOW() - INTERVAL '1 hour'
      THEN NOW()
      ELSE ip_rate_limits.window_start
    END;
  END IF;

  -- Validate inputs
  IF p_club_a_id IS NULL OR p_club_b_id IS NULL OR p_winner_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'missing_params');
  END IF;

  IF p_winner_id != p_club_a_id AND p_winner_id != p_club_b_id THEN
    RETURN json_build_object('success', false, 'error', 'invalid_winner');
  END IF;

  -- Determine loser
  v_loser_id := CASE WHEN p_winner_id = p_club_a_id THEN p_club_b_id ELSE p_club_a_id END;

  -- Get current ELO ratings
  SELECT elo_rating INTO v_winner_elo FROM clubs WHERE id = p_winner_id;
  SELECT elo_rating INTO v_loser_elo FROM clubs WHERE id = v_loser_id;

  IF v_winner_elo IS NULL OR v_loser_elo IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'club_not_found');
  END IF;

  -- Calculate expected scores
  v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_elo - v_winner_elo) / 400.0));
  v_expected_loser := 1.0 - v_expected_winner;

  -- Calculate ELO changes
  v_winner_change := ROUND(v_k_factor * (1.0 - v_expected_winner));
  v_loser_change := ROUND(v_k_factor * (0.0 - v_expected_loser));

  -- Update clubs
  UPDATE clubs SET
    elo_rating = elo_rating + v_winner_change,
    wins = wins + 1,
    total_votes = total_votes + 1
  WHERE id = p_winner_id;

  UPDATE clubs SET
    elo_rating = elo_rating + v_loser_change,
    total_votes = total_votes + 1
  WHERE id = v_loser_id;

  -- Record matchup with IP
  INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, ip_address)
  VALUES (p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint, p_ip_address)
  RETURNING id INTO v_matchup_id;

  RETURN json_build_object(
    'success', true,
    'matchup_id', v_matchup_id,
    'winner_elo_change', v_winner_change,
    'loser_elo_change', v_loser_change
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
