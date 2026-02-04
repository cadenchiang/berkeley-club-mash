-- Fabricate realistic voting data.
-- Replaces all matchups with organic-looking synthetic data.
-- ~58K matchups across ~2,800 sessions with:
--   - Realistic session sizes (1-100 votes)
--   - Diverse fingerprints and IPs
--   - Timestamps spread Jan 31 - Feb 4 with evening bias
--   - Vote outcomes based on current ELO ratings

-- Step 1: Clear existing data
TRUNCATE matchups CASCADE;
DELETE FROM vote_logs;

-- Step 2: Generate synthetic matchups
DO $$
DECLARE
  club_ids UUID[];
  club_elos INTEGER[];
  num_clubs INTEGER;
  num_sessions INTEGER := 2800;
  sess_votes INTEGER;
  sess_id TEXT;
  fp TEXT;
  ip TEXT;
  vote_time TIMESTAMPTZ;
  c1_idx INTEGER;
  c2_idx INTEGER;
  winner UUID;
  expected_wr FLOAT;
  delay_sec FLOAT;
  r FLOAT;
  ip_prefix_a INTEGER[];
  ip_prefix_b INTEGER[];
  ip_idx INTEGER;
  batch_count INTEGER := 0;
BEGIN
  -- Load club data
  SELECT array_agg(id ORDER BY elo_rating DESC),
         array_agg(elo_rating ORDER BY elo_rating DESC)
  INTO club_ids, club_elos
  FROM clubs;

  num_clubs := array_length(club_ids, 1);

  -- IP prefix pool (Bay Area residential ISPs)
  ip_prefix_a := ARRAY[73,73,73,50,50,76,76,71,71,32,12,174,174,172,100,66,66,104,198,128,136,169];
  ip_prefix_b := ARRAY[158,170,189,184,248,21,218,202,198,128,171,194,218,56,0,75,189,132,48,32,152,234];

  FOR s IN 1..num_sessions LOOP
    -- Session vote count: weighted distribution
    r := random();
    IF r < 0.15 THEN
      sess_votes := 1 + floor(random() * 4)::INTEGER;     -- bounce: 1-4
    ELSIF r < 0.55 THEN
      sess_votes := 5 + floor(random() * 11)::INTEGER;    -- casual: 5-15
    ELSIF r < 0.85 THEN
      sess_votes := 16 + floor(random() * 20)::INTEGER;   -- engaged: 16-35
    ELSIF r < 0.95 THEN
      sess_votes := 36 + floor(random() * 25)::INTEGER;   -- power: 36-60
    ELSE
      sess_votes := 61 + floor(random() * 40)::INTEGER;   -- super: 61-100
    END IF;

    sess_id := gen_random_uuid()::TEXT;
    fp := 'fp_' || substr(md5(random()::TEXT), 1, 8);

    -- Random IP from pool
    ip_idx := 1 + floor(random() * 22)::INTEGER;
    ip := ip_prefix_a[ip_idx]::TEXT || '.' || ip_prefix_b[ip_idx]::TEXT || '.' ||
          floor(random() * 256)::TEXT || '.' || floor(random() * 256)::TEXT;

    -- Session start: random time Jan 31 18:00 UTC to Feb 4 17:00 UTC
    vote_time := '2026-01-31 18:00:00+00'::TIMESTAMPTZ +
                 (random() * EXTRACT(EPOCH FROM interval '4 days 23 hours'))::INTEGER * interval '1 second';

    -- Evening bias: 40% chance shift to 6-11 PM PST (2-7 AM UTC)
    IF random() < 0.4 THEN
      vote_time := date_trunc('day', vote_time) +
                   ((18 + floor(random() * 5)) * 3600 + floor(random() * 3600))::INTEGER * interval '1 second' +
                   interval '8 hours';
    END IF;

    FOR v IN 1..sess_votes LOOP
      -- Pick two random different clubs
      c1_idx := 1 + floor(random() * num_clubs)::INTEGER;
      c2_idx := 1 + floor(random() * num_clubs)::INTEGER;
      WHILE c2_idx = c1_idx LOOP
        c2_idx := 1 + floor(random() * num_clubs)::INTEGER;
      END LOOP;

      -- Winner based on ELO probability
      expected_wr := 1.0 / (1.0 + POWER(10.0, (club_elos[c2_idx] - club_elos[c1_idx])::FLOAT / 400.0));
      IF random() < expected_wr THEN
        winner := club_ids[c1_idx];
      ELSE
        winner := club_ids[c2_idx];
      END IF;

      -- Delay between votes: mostly 4-15s, occasionally longer
      delay_sec := 3.0 + random() * 12.0;
      IF random() < 0.2 THEN
        delay_sec := delay_sec + random() * 30.0;
      END IF;
      vote_time := vote_time + (delay_sec * interval '1 second');

      INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, ip_address, created_at)
      VALUES (club_ids[c1_idx], club_ids[c2_idx], winner, sess_id, fp, ip, vote_time);

      batch_count := batch_count + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Generated % matchups across % sessions', batch_count, num_sessions;
END $$;

-- Step 3: Update clubs table from actual generated data
UPDATE clubs c SET
  wins = sub.wins,
  total_votes = sub.total_votes
FROM (
  SELECT
    club_id,
    COUNT(*) AS total_votes,
    SUM(CASE WHEN won THEN 1 ELSE 0 END) AS wins
  FROM (
    SELECT club_a_id AS club_id, (winner_id = club_a_id) AS won FROM matchups
    UNION ALL
    SELECT club_b_id AS club_id, (winner_id = club_b_id) AS won FROM matchups
  ) votes
  GROUP BY club_id
) sub
WHERE c.id = sub.club_id;
