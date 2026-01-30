-- FIX: Recalculate all ELO ratings from actual matchup history
-- This does NOT delete any data - just recomputes accurate ratings
-- Fixes the Innovative Design anomaly (1622 ELO with 34.5% win rate)

-- Step 1: Reset all clubs to baseline
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

-- Step 2: Recalculate from all matchups
CREATE OR REPLACE FUNCTION recalculate_all_elos()
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
  v_count INTEGER := 0;
BEGIN
  -- Process all matchups in chronological order
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_count := v_count + 1;
    v_loser_id := CASE WHEN matchup.winner_id = matchup.club_a_id THEN matchup.club_b_id ELSE matchup.club_a_id END;

    -- Get current ratings
    SELECT elo_rating, total_votes INTO v_winner_rating, v_winner_total FROM clubs WHERE id = matchup.winner_id;
    SELECT elo_rating, total_votes INTO v_loser_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

    -- FIDE K-factor
    IF v_winner_total < 30 THEN v_k_winner := 40;
    ELSIF v_winner_rating >= 1800 AND v_winner_total >= 200 THEN v_k_winner := 10;
    ELSE v_k_winner := 20;
    END IF;

    IF v_loser_total < 30 THEN v_k_loser := 40;
    ELSIF v_loser_rating >= 1800 AND v_loser_total >= 200 THEN v_k_loser := 10;
    ELSE v_k_loser := 20;
    END IF;

    -- Calculate expected score and new ratings
    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
    v_new_winner_rating := GREATEST(100, ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner)));
    v_new_loser_rating := GREATEST(100, ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner))));

    -- Update clubs
    UPDATE clubs SET elo_rating = v_new_winner_rating, total_votes = total_votes + 1, wins = wins + 1 WHERE id = matchup.winner_id;
    UPDATE clubs SET elo_rating = v_new_loser_rating, total_votes = total_votes + 1 WHERE id = v_loser_id;
  END LOOP;

  RAISE NOTICE 'Recalculated ELO from % matchups', v_count;
END;
$$ LANGUAGE plpgsql;

SELECT recalculate_all_elos();
DROP FUNCTION recalculate_all_elos();
