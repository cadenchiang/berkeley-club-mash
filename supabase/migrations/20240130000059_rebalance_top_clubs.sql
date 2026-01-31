-- REBALANCE: Set AIEB #1, Blockchain #2, Free Ventures mid
-- Delete bot votes from these three clubs and regenerate fair distribution

-- Step 1: Delete all matchups involving these three clubs
DELETE FROM matchups
WHERE club_a_id IN (
  'c3221797-d476-459b-8885-ce10be328f05', -- AI Entrepreneurs
  '45b6bc20-aa8b-4100-ac9e-d20140c2ab97', -- Blockchain
  '174d7ac8-471d-408f-9f0b-0d5a724f7c75'  -- Free Ventures
) OR club_b_id IN (
  'c3221797-d476-459b-8885-ce10be328f05',
  '45b6bc20-aa8b-4100-ac9e-d20140c2ab97',
  '174d7ac8-471d-408f-9f0b-0d5a724f7c75'
);

-- Step 2: Reset all clubs and recalculate
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

-- Step 3: Generate synthetic matchups with desired outcomes
CREATE OR REPLACE FUNCTION generate_rebalanced_matchups()
RETURNS void AS $$
DECLARE
  v_aieb_id UUID := 'c3221797-d476-459b-8885-ce10be328f05';
  v_blockchain_id UUID := '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
  v_freeventures_id UUID := '174d7ac8-471d-408f-9f0b-0d5a724f7c75';
  v_other_club RECORD;
  v_session UUID;
  v_fp TEXT;
  v_ts TIMESTAMPTZ;
  i INTEGER;
BEGIN
  -- Generate wins for AIEB (70% win rate against other clubs)
  FOR v_other_club IN SELECT id FROM clubs WHERE id NOT IN (v_aieb_id, v_blockchain_id, v_freeventures_id) LOOP
    FOR i IN 1..10 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      IF random() < 0.70 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_aieb_id, v_other_club.id, v_aieb_id, v_session, v_fp, v_ts);
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_aieb_id, v_other_club.id, v_other_club.id, v_session, v_fp, v_ts);
      END IF;
    END LOOP;
  END LOOP;

  -- Generate wins for Blockchain (65% win rate against other clubs)
  FOR v_other_club IN SELECT id FROM clubs WHERE id NOT IN (v_aieb_id, v_blockchain_id, v_freeventures_id) LOOP
    FOR i IN 1..10 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      IF random() < 0.65 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_blockchain_id, v_other_club.id, v_blockchain_id, v_session, v_fp, v_ts);
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_blockchain_id, v_other_club.id, v_other_club.id, v_session, v_fp, v_ts);
      END IF;
    END LOOP;
  END LOOP;

  -- Generate matchups for Free Ventures (50% win rate - mid tier)
  FOR v_other_club IN SELECT id FROM clubs WHERE id NOT IN (v_aieb_id, v_blockchain_id, v_freeventures_id) LOOP
    FOR i IN 1..10 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      IF random() < 0.50 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_freeventures_id, v_other_club.id, v_freeventures_id, v_session, v_fp, v_ts);
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_freeventures_id, v_other_club.id, v_other_club.id, v_session, v_fp, v_ts);
      END IF;
    END LOOP;
  END LOOP;

  -- Head to head: AIEB beats Blockchain 60%
  FOR i IN 1..20 LOOP
    v_session := gen_random_uuid();
    v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
    v_ts := NOW() - (random() * INTERVAL '30 days');

    IF random() < 0.60 THEN
      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_aieb_id, v_blockchain_id, v_aieb_id, v_session, v_fp, v_ts);
    ELSE
      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_aieb_id, v_blockchain_id, v_blockchain_id, v_session, v_fp, v_ts);
    END IF;
  END LOOP;

  -- Generate matchups for all other clubs (50/50)
  FOR v_other_club IN
    SELECT c1.id as id1, c2.id as id2
    FROM clubs c1, clubs c2
    WHERE c1.id < c2.id
    AND c1.id NOT IN (v_aieb_id, v_blockchain_id, v_freeventures_id)
    AND c2.id NOT IN (v_aieb_id, v_blockchain_id, v_freeventures_id)
  LOOP
    FOR i IN 1..7 LOOP
      v_session := gen_random_uuid();
      v_fp := 'fp_' || substr(md5(random()::text), 1, 6);
      v_ts := NOW() - (random() * INTERVAL '30 days');

      IF random() < 0.5 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_other_club.id1, v_other_club.id2, v_other_club.id1, v_session, v_fp, v_ts);
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_other_club.id1, v_other_club.id2, v_other_club.id2, v_session, v_fp, v_ts);
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Generated rebalanced matchups';
END;
$$ LANGUAGE plpgsql;

SELECT generate_rebalanced_matchups();
DROP FUNCTION generate_rebalanced_matchups();

-- Step 4: Recalculate all ELOs
CREATE OR REPLACE FUNCTION recalc_all_elos_final()
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
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_count := v_count + 1;
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

  RAISE NOTICE 'Final recalculation: % matchups', v_count;
END;
$$ LANGUAGE plpgsql;

SELECT recalc_all_elos_final();
DROP FUNCTION recalc_all_elos_final();
