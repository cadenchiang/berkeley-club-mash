-- PROPER ELO SYSTEM: Generate matchups that produce sensible rankings
--
-- Key insight: ELO spread of ~300 points (1400-1700) requires:
-- - Top vs bottom: ~85% win rate for top
-- - Adjacent ranks: ~52% win rate for higher
--
-- Formula: Expected win rate = 1 / (1 + 10^(-rating_diff/400))

-- Step 1: Clear everything
DELETE FROM matchups;
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

-- Step 2: Define desired ranking order (AIEB #1, Blockchain #2, etc.)
-- and generate matchups with proper win probabilities

CREATE OR REPLACE FUNCTION generate_proper_matchups()
RETURNS void AS $$
DECLARE
  v_ranked_clubs UUID[];
  v_club_count INTEGER;
  i INTEGER;
  j INTEGER;
  k INTEGER;
  v_rank_diff INTEGER;
  v_elo_diff FLOAT;
  v_win_prob FLOAT;
  v_matches_per_pair INTEGER := 8;
BEGIN
  -- Get clubs in desired order: AIEB first, Blockchain second, then others by current name order
  -- We'll manually set the top 2, rest alphabetically for fairness

  WITH ranked AS (
    SELECT id, name,
      CASE
        WHEN name = 'AI Entrepreneurs at Berkeley' THEN 1
        WHEN name = 'Blockchain' THEN 2
        ELSE 100 + ROW_NUMBER() OVER (ORDER BY name)
      END as desired_rank
    FROM clubs
    ORDER BY desired_rank
  )
  SELECT ARRAY_AGG(id ORDER BY desired_rank) INTO v_ranked_clubs FROM ranked;

  v_club_count := array_length(v_ranked_clubs, 1);

  RAISE NOTICE 'Generating matchups for % clubs', v_club_count;

  -- Generate matchups between all pairs
  FOR i IN 1..v_club_count LOOP
    FOR j IN (i+1)..v_club_count LOOP
      -- Calculate expected ELO difference based on rank
      -- Spread of ~4 ELO points per rank = ~280 point total spread
      v_rank_diff := j - i;
      v_elo_diff := v_rank_diff * 4.0;

      -- Calculate win probability for higher ranked club
      -- E = 1 / (1 + 10^(-diff/400))
      v_win_prob := 1.0 / (1.0 + POWER(10.0, -v_elo_diff / 400.0));

      -- Generate matches
      FOR k IN 1..v_matches_per_pair LOOP
        IF random() < v_win_prob THEN
          -- Higher ranked (i) wins
          INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
          VALUES (v_ranked_clubs[i], v_ranked_clubs[j], v_ranked_clubs[i],
                  gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6),
                  NOW() - (random() * INTERVAL '30 days'));
        ELSE
          -- Lower ranked (j) wins - upset
          INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
          VALUES (v_ranked_clubs[i], v_ranked_clubs[j], v_ranked_clubs[j],
                  gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6),
                  NOW() - (random() * INTERVAL '30 days'));
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Generated % matchups', v_club_count * (v_club_count - 1) / 2 * v_matches_per_pair;
END;
$$ LANGUAGE plpgsql;

SELECT generate_proper_matchups();
DROP FUNCTION generate_proper_matchups();

-- Step 3: Recalculate ELO from matchups
CREATE OR REPLACE FUNCTION recalculate_elo()
RETURNS void AS $$
DECLARE
  m RECORD;
  v_loser_id UUID;
  v_winner_elo INTEGER;
  v_loser_elo INTEGER;
  v_winner_games INTEGER;
  v_loser_games INTEGER;
  v_k_winner INTEGER;
  v_k_loser INTEGER;
  v_expected FLOAT;
  v_winner_delta INTEGER;
  v_loser_delta INTEGER;
BEGIN
  FOR m IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_loser_id := CASE WHEN m.winner_id = m.club_a_id THEN m.club_b_id ELSE m.club_a_id END;

    SELECT elo_rating, total_votes INTO v_winner_elo, v_winner_games FROM clubs WHERE id = m.winner_id;
    SELECT elo_rating, total_votes INTO v_loser_elo, v_loser_games FROM clubs WHERE id = v_loser_id;

    -- K-factor: higher for new clubs, lower for established
    v_k_winner := CASE
      WHEN v_winner_games < 30 THEN 40
      WHEN v_winner_elo >= 1800 AND v_winner_games >= 200 THEN 10
      ELSE 20
    END;
    v_k_loser := CASE
      WHEN v_loser_games < 30 THEN 40
      WHEN v_loser_elo >= 1800 AND v_loser_games >= 200 THEN 10
      ELSE 20
    END;

    -- Expected score for winner
    v_expected := 1.0 / (1.0 + POWER(10.0, (v_loser_elo - v_winner_elo)::FLOAT / 400.0));

    -- ELO changes
    v_winner_delta := ROUND(v_k_winner * (1.0 - v_expected));
    v_loser_delta := ROUND(v_k_loser * (0.0 - (1.0 - v_expected)));

    -- Update winner
    UPDATE clubs SET
      elo_rating = GREATEST(100, elo_rating + v_winner_delta),
      total_votes = total_votes + 1,
      wins = wins + 1
    WHERE id = m.winner_id;

    -- Update loser
    UPDATE clubs SET
      elo_rating = GREATEST(100, elo_rating + v_loser_delta),
      total_votes = total_votes + 1
    WHERE id = v_loser_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT recalculate_elo();
DROP FUNCTION recalculate_elo();
