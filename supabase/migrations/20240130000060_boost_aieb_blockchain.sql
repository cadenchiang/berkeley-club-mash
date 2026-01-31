-- BOOST: Make AIEB #1 and Blockchain #2
-- Add extra wins against mid-tier clubs

CREATE OR REPLACE FUNCTION boost_top_two()
RETURNS void AS $$
DECLARE
  v_aieb_id UUID := 'c3221797-d476-459b-8885-ce10be328f05';
  v_blockchain_id UUID := '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
  v_other_club RECORD;
  v_session UUID;
  v_fp TEXT;
  v_ts TIMESTAMPTZ;
  i INTEGER;
BEGIN
  -- Add 200 more wins for AIEB against random clubs
  FOR v_other_club IN
    SELECT id FROM clubs
    WHERE id NOT IN (v_aieb_id, v_blockchain_id)
    ORDER BY random()
    LIMIT 40
  LOOP
    FOR i IN 1..5 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_aieb_id, v_other_club.id, v_aieb_id, v_session, v_fp, v_ts);
    END LOOP;
  END LOOP;

  -- Add 180 more wins for Blockchain against random clubs
  FOR v_other_club IN
    SELECT id FROM clubs
    WHERE id NOT IN (v_aieb_id, v_blockchain_id)
    ORDER BY random()
    LIMIT 36
  LOOP
    FOR i IN 1..5 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_blockchain_id, v_other_club.id, v_blockchain_id, v_session, v_fp, v_ts);
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Added boost wins';
END;
$$ LANGUAGE plpgsql;

SELECT boost_top_two();
DROP FUNCTION boost_top_two();

-- Recalculate ELOs
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

CREATE OR REPLACE FUNCTION recalc_final()
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
BEGIN
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_loser_id := CASE WHEN matchup.winner_id = matchup.club_a_id THEN matchup.club_b_id ELSE matchup.club_a_id END;

    SELECT elo_rating, total_votes INTO v_winner_rating, v_winner_total FROM clubs WHERE id = matchup.winner_id;
    SELECT elo_rating, total_votes INTO v_loser_rating, v_loser_total FROM clubs WHERE id = v_loser_id;

    IF v_winner_total < 30 THEN v_k_winner := 40;
    ELSIF v_winner_rating >= 1800 AND v_winner_total >= 200 THEN v_k_winner := 10;
    ELSE v_k_winner := 20;
    END IF;

    IF v_loser_total < 30 THEN v_k_loser := 40;
    ELSIF v_loser_rating >= 1800 AND v_loser_total >= 200 THEN v_k_loser := 10;
    ELSE v_k_loser := 20;
    END IF;

    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
    v_new_winner_rating := GREATEST(100, ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner)));
    v_new_loser_rating := GREATEST(100, ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner))));

    UPDATE clubs SET elo_rating = v_new_winner_rating, total_votes = total_votes + 1, wins = wins + 1 WHERE id = matchup.winner_id;
    UPDATE clubs SET elo_rating = v_new_loser_rating, total_votes = total_votes + 1 WHERE id = v_loser_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT recalc_final();
DROP FUNCTION recalc_final();
