-- CLEANUP ALL REMAINING BOT MATCHUPS
-- The bots were also voting AGAINST Entrepreneurs @ Berkeley
-- Delete ALL matchups from bot sessions/fingerprints, not just ones where they won

-- Step 1: Delete ALL matchups with fp_worker fingerprints (regardless of winner)
DELETE FROM matchups
WHERE fingerprint LIKE 'fp_worker%';

-- Step 2: Delete ALL matchups from hardcoded bot sessions
DELETE FROM matchups
WHERE session_id LIKE '550e8400-e29b-41d4-a716-446655%';

-- Step 3: Recalculate ALL club stats from remaining clean matchups
-- Reset all clubs
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

-- Create function to recalculate
CREATE OR REPLACE FUNCTION recalculate_all_elos_clean()
RETURNS void AS $$
DECLARE
  matchup RECORD;
  v_winner_rating INTEGER;
  v_loser_rating INTEGER;
  v_winner_total INTEGER;
  v_loser_total INTEGER;
  v_k_winner INTEGER;
  v_k_loser INTEGER;
  v_expected_winner FLOAT;
  v_new_winner_rating INTEGER;
  v_new_loser_rating INTEGER;
  v_loser_id UUID;
  v_matchup_count INTEGER := 0;
BEGIN
  -- Replay all remaining matchups in chronological order
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

    -- FIDE-style K-factor
    IF v_winner_total < 30 THEN
      v_k_winner := 40;
    ELSIF v_winner_rating >= 1800 AND v_winner_total >= 200 THEN
      v_k_winner := 10;
    ELSE
      v_k_winner := 20;
    END IF;

    IF v_loser_total < 30 THEN
      v_k_loser := 40;
    ELSIF v_loser_rating >= 1800 AND v_loser_total >= 200 THEN
      v_k_loser := 10;
    ELSE
      v_k_loser := 20;
    END IF;

    -- Expected score
    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));

    -- New ratings (NO UPPER BOUND)
    v_new_winner_rating := ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner));
    v_new_loser_rating := ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner)));

    -- Only enforce minimum of 100
    v_new_winner_rating := GREATEST(100, v_new_winner_rating);
    v_new_loser_rating := GREATEST(100, v_new_loser_rating);

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

  RAISE NOTICE 'Clean ELO recalculation complete: % legitimate matchups', v_matchup_count;
END;
$$ LANGUAGE plpgsql;

-- Run the recalculation
SELECT recalculate_all_elos_clean();

-- Drop the temporary function
DROP FUNCTION recalculate_all_elos_clean();
