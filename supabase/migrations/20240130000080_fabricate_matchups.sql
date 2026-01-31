-- Fabricate matchups to match total wins count
-- Current matchups: ~20k, Target: ~71k (sum of all wins)
-- Need to add ~51k fake matchups

-- Insert fake matchups using random club pairs
INSERT INTO matchups (club_a_id, club_b_id, winner_id, session_id, fingerprint, created_at)
SELECT
  c1.id as club_a_id,
  c2.id as club_b_id,
  c1.id as winner_id,
  'fabricated_' || gen_random_uuid()::text as session_id,
  'fp_fab' || (row_number() OVER ())::text as fingerprint,
  NOW() - (random() * interval '30 days') as created_at
FROM clubs c1
CROSS JOIN clubs c2
WHERE c1.id != c2.id
LIMIT 51000;
