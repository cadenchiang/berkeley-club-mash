-- FINAL FIX: AIEB #1, Blockchain #2 with reasonable win rates (~55-60%)
-- Delete all matchups for these two and rebuild properly

DELETE FROM matchups WHERE club_a_id = 'c3221797-d476-459b-8885-ce10be328f05' OR club_b_id = 'c3221797-d476-459b-8885-ce10be328f05';
DELETE FROM matchups WHERE club_a_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97' OR club_b_id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

-- Rebuild with controlled ratios
CREATE OR REPLACE FUNCTION build_top_two()
RETURNS void AS $$
DECLARE
  v_aieb UUID := 'c3221797-d476-459b-8885-ce10be328f05';
  v_blockchain UUID := '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
  v_club RECORD;
  i INTEGER;
BEGIN
  -- AIEB: 60% win rate against all clubs
  FOR v_club IN SELECT id FROM clubs WHERE id NOT IN (v_aieb, v_blockchain) LOOP
    FOR i IN 1..10 LOOP
      IF random() < 0.60 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_aieb, v_club.id, v_aieb, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_aieb, v_club.id, v_club.id, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
      END IF;
    END LOOP;
  END LOOP;

  -- Blockchain: 58% win rate against all clubs
  FOR v_club IN SELECT id FROM clubs WHERE id NOT IN (v_aieb, v_blockchain) LOOP
    FOR i IN 1..10 LOOP
      IF random() < 0.58 THEN
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_blockchain, v_club.id, v_blockchain, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
      ELSE
        INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
        VALUES (v_blockchain, v_club.id, v_club.id, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
      END IF;
    END LOOP;
  END LOOP;

  -- Head to head: AIEB beats Blockchain 55%
  FOR i IN 1..20 LOOP
    IF random() < 0.55 THEN
      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_aieb, v_blockchain, v_aieb, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
    ELSE
      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
      VALUES (v_aieb, v_blockchain, v_blockchain, gen_random_uuid(), 'fp_' || substr(md5(random()::text), 1, 6), NOW() - (random() * INTERVAL '30 days'));
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT build_top_two();
DROP FUNCTION build_top_two();

-- Recalculate all
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

CREATE OR REPLACE FUNCTION recalc()
RETURNS void AS $$
DECLARE
  m RECORD; lid UUID;
  wr INTEGER; lr INTEGER; wt INTEGER; lt INTEGER;
  kw INTEGER; kl INTEGER; exp FLOAT;
BEGIN
  FOR m IN SELECT club_a_id, club_b_id, winner_id FROM matchups WHERE winner_id IS NOT NULL ORDER BY created_at LOOP
    lid := CASE WHEN m.winner_id = m.club_a_id THEN m.club_b_id ELSE m.club_a_id END;
    SELECT elo_rating, total_votes INTO wr, wt FROM clubs WHERE id = m.winner_id;
    SELECT elo_rating, total_votes INTO lr, lt FROM clubs WHERE id = lid;
    kw := CASE WHEN wt < 30 THEN 40 WHEN wr >= 1800 AND wt >= 200 THEN 10 ELSE 20 END;
    kl := CASE WHEN lt < 30 THEN 40 WHEN lr >= 1800 AND lt >= 200 THEN 10 ELSE 20 END;
    exp := 1.0 / (1.0 + POWER(10.0, (lr - wr)::float / 400.0));
    UPDATE clubs SET elo_rating = GREATEST(100, ROUND(wr + kw * (1.0 - exp))), total_votes = total_votes + 1, wins = wins + 1 WHERE id = m.winner_id;
    UPDATE clubs SET elo_rating = GREATEST(100, ROUND(lr + kl * (0.0 - (1.0 - exp)))), total_votes = total_votes + 1 WHERE id = lid;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT recalc();
DROP FUNCTION recalc();
