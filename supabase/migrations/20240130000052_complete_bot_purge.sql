-- COMPLETE BOT PURGE: Remove all suspicious voting activity
--
-- Audit found 17,711 suspicious votes (88.7% of all votes)
-- Criteria for BOT activity:
-- 1. Sessions with > 50 votes (real users don't vote 200+ times)
-- 2. Fingerprints with > 100 votes (real users don't have 1000+ votes)
-- 3. High-volume fingerprints used for vote manipulation

-- Step 1: Delete votes from high-volume sessions (>50 votes per session)
DELETE FROM matchups
WHERE session_id IN (
  SELECT session_id
  FROM matchups
  GROUP BY session_id
  HAVING COUNT(*) > 50
);

-- Step 2: Delete votes from high-volume fingerprints (>100 votes per fingerprint)
DELETE FROM matchups
WHERE fingerprint IN (
  SELECT fingerprint
  FROM matchups
  WHERE fingerprint IS NOT NULL
  GROUP BY fingerprint
  HAVING COUNT(*) > 100
);

-- Step 3: Delete specific known bot fingerprints identified in audit
DELETE FROM matchups
WHERE fingerprint IN (
  'fp_yisgc5', 'fp_dhx48c', 'fp_44mi5p', 'fp_lvlhhy', 'fp_htr5tx',
  'fp_l0n7qk', 'fp_l3v393', 'fp_zenwfx', 'fp_bqc6b0', 'fp_g3bd9h',
  'fp_i7nazu', 'fp_cwpwrl', 'fp_vysc73', 'fp_c46pf7', 'fp_uduhoq',
  'fp_o99b5c', 'fp_poisil', 'fp_3nf18s', 'fp_dnd9mf', 'fp_e9p456',
  'fp_oypllf', 'fp_ine21a', 'fp_gpn7s8', 'fp_2ch016', 'fp_i8l1e9',
  'fp_z0uhjt', 'fp_mjxzly', 'fp_932l6h', 'fp_uk1ri7', 'fp_1370t2',
  'fp_j4nz9w', 'fp_wuqgfd', 'fp_5jk8bl', 'fp_o0ag53', 'fp_v2jxfw',
  'fp_n1154m', 'fp_y4e24s', 'fp_yci7c1', 'fp_oxvfnr', 'fp_2ormcc',
  'fp_6kq3c8', 'fp_oq8642', 'fp_swdmm8', 'fp_umbx63', 'fp_zbp736',
  'fp_2o5q8b', 'fp_p7712s', 'fp_rxwq8c', 'fp_zcv9pw', 'fp_x521j0',
  'fp_a9s29i', 'fp_abc123xyz'
);

-- Step 4: Delete remaining medium-volume fingerprints (>50 votes - still suspicious)
DELETE FROM matchups
WHERE fingerprint IN (
  SELECT fingerprint
  FROM matchups
  WHERE fingerprint IS NOT NULL
  GROUP BY fingerprint
  HAVING COUNT(*) > 50
);

-- Step 5: Ban all these fingerprints to prevent future abuse
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at)
SELECT DISTINCT NULL, fingerprint, 'Bot activity: high volume fingerprint', NULL::TIMESTAMPTZ
FROM matchups
WHERE fingerprint IN (
  'fp_yisgc5', 'fp_dhx48c', 'fp_44mi5p', 'fp_lvlhhy', 'fp_htr5tx',
  'fp_l0n7qk', 'fp_l3v393', 'fp_zenwfx', 'fp_bqc6b0', 'fp_g3bd9h'
)
ON CONFLICT DO NOTHING;

-- Step 6: Recalculate ALL club stats from clean data
-- Reset everything
UPDATE clubs SET elo_rating = 1500, total_votes = 0, wins = 0;

-- Recalculate function
CREATE OR REPLACE FUNCTION recalculate_elos_clean_v2()
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
  -- Replay all remaining clean matchups
  FOR matchup IN
    SELECT club_a_id, club_b_id, winner_id
    FROM matchups
    WHERE winner_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    v_matchup_count := v_matchup_count + 1;
    v_loser_id := CASE WHEN matchup.winner_id = matchup.club_a_id THEN matchup.club_b_id ELSE matchup.club_a_id END;

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

    v_expected_winner := 1.0 / (1.0 + POWER(10.0, (v_loser_rating - v_winner_rating)::float / 400.0));
    v_new_winner_rating := GREATEST(100, ROUND(v_winner_rating + v_k_winner * (1.0 - v_expected_winner)));
    v_new_loser_rating := GREATEST(100, ROUND(v_loser_rating + v_k_loser * (0.0 - (1.0 - v_expected_winner))));

    UPDATE clubs SET elo_rating = v_new_winner_rating, total_votes = total_votes + 1, wins = wins + 1 WHERE id = matchup.winner_id;
    UPDATE clubs SET elo_rating = v_new_loser_rating, total_votes = total_votes + 1 WHERE id = v_loser_id;
  END LOOP;

  RAISE NOTICE 'Clean recalculation complete: % matchups', v_matchup_count;
END;
$$ LANGUAGE plpgsql;

SELECT recalculate_elos_clean_v2();
DROP FUNCTION recalculate_elos_clean_v2();
