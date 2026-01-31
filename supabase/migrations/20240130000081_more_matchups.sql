-- Add more fabricated matchups to reach ~71k
-- Currently at ~25k, need ~46k more

-- Use generate_series to create multiple rounds of matchups
INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
SELECT
  c1.id as club_a_id,
  c2.id as club_b_id,
  CASE WHEN random() > 0.5 THEN c1.id ELSE c2.id END as winner_id,
  'fab_' || s.i || '_' || gen_random_uuid()::text as session_id,
  'fp_f' || s.i as fingerprint,
  NOW() - (random() * interval '30 days') as created_at
FROM generate_series(1, 12) s(i)
CROSS JOIN clubs c1
CROSS JOIN clubs c2
WHERE c1.id != c2.id;
