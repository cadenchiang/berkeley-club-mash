-- RESET: Generate realistic stats while preserving ranking order
-- All clubs get ~500-600 votes with ~50-55% win rates
-- Higher ranked clubs slightly more likely to win vs lower ranked

-- Clear all matchups
DELETE FROM matchups;

-- Generate realistic matchups
CREATE OR REPLACE FUNCTION generate_realistic()
RETURNS void AS $$
DECLARE
  v_clubs UUID[];
  v_count INTEGER;
  i INTEGER;
  j INTEGER;
  k INTEGER;
  v_win_prob FLOAT;
  v_session UUID;
  v_fp TEXT;
BEGIN
  -- Get clubs in current ELO order (will be recalculated)
  SELECT ARRAY_AGG(id ORDER BY elo_rating DESC) INTO v_clubs FROM clubs;
  v_count := array_length(v_clubs, 1);

  -- Generate matchups between all pairs
  FOR i IN 1..v_count LOOP
    FOR j IN (i+1)..v_count LOOP
      -- Higher ranked club (i) has slightly better odds
      -- Difference in rank affects win probability: 52-58% for higher ranked
      v_win_prob := 0.50 + (j - i)::float / v_count * 0.15;
      v_win_prob := LEAST(v_win_prob, 0.58); -- Cap at 58%

      -- Generate 7-9 matchups per pair
      FOR k IN 1..8 LOOP
        v_session := gen_random_uuid();
        v_fp := 'fp_' || substr(md5(random()::text), 1, 6);

        IF random() < v_win_prob THEN
          -- Higher ranked wins
          INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
          VALUES (v_clubs[i], v_clubs[j], v_clubs[i], v_session, v_fp, NOW() - (random() * INTERVAL '30 days'));
        ELSE
          -- Lower ranked wins (upset)
          INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
          VALUES (v_clubs[i], v_clubs[j], v_clubs[j], v_session, v_fp, NOW() - (random() * INTERVAL '30 days'));
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Generated realistic matchups';
END;
$$ LANGUAGE plpgsql;

SELECT generate_realistic();
DROP FUNCTION generate_realistic();

-- Recalculate all ELOs from scratch
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

CREATE OR REPLACE FUNCTION recalc_elos()
RETURNS void AS $$
DECLARE
  m RECORD;
  lid UUID;
  wr INTEGER; lr INTEGER;
  wt INTEGER; lt INTEGER;
  kw INTEGER; kl INTEGER;
  exp FLOAT;
BEGIN
  FOR m IN SELECT club_a_id, club_b_id, winner_id FROM matchups WHERE winner_id IS NOT NULL ORDER BY created_at LOOP
    lid := CASE WHEN m.winner_id = m.club_a_id THEN m.club_b_id ELSE m.club_a_id END;

    SELECT elo_rating, total_votes INTO wr, wt FROM clubs WHERE id = m.winner_id;
    SELECT elo_rating, total_votes INTO lr, lt FROM clubs WHERE id = lid;

    kw := CASE WHEN wt < 30 THEN 40 WHEN wr >= 1800 AND wt >= 200 THEN 10 ELSE 20 END;
    kl := CASE WHEN lt < 30 THEN 40 WHEN lr >= 1800 AND lt >= 200 THEN 10 ELSE 20 END;

    exp := 1.0 / (1.0 + POWER(10.0, (lr - wr)::float / 400.0));

    UPDATE clubs SET
      elo_rating = GREATEST(100, ROUND(wr + kw * (1.0 - exp))),
      total_votes = total_votes + 1,
      wins = wins + 1
    WHERE id = m.winner_id;

    UPDATE clubs SET
      elo_rating = GREATEST(100, ROUND(lr + kl * (0.0 - (1.0 - exp)))),
      total_votes = total_votes + 1
    WHERE id = lid;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT recalc_elos();
DROP FUNCTION recalc_elos();
