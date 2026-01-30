-- BAN BETA ALPHA PSI BOT
-- Session a59afc48-82bd-47e7-8ec5-7a1aa4fe58e2 voted 103 times, ALL for Beta Alpha Psi
-- Votes every 10 seconds like clockwork - clear bot behavior

-- Ban the session and fingerprint
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at)
VALUES
  ('a59afc48-82bd-47e7-8ec5-7a1aa4fe58e2', 'fp_o0ag53', 'Bot: 103 votes, 100% for Beta Alpha Psi', NULL)
ON CONFLICT DO NOTHING;

-- Delete all votes from this bot session
DELETE FROM matchups
WHERE session_id = 'a59afc48-82bd-47e7-8ec5-7a1aa4fe58e2';

-- Recalculate Beta Alpha Psi stats from remaining legitimate votes
UPDATE clubs SET
  wins = (SELECT COUNT(*) FROM matchups WHERE winner_id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b'),
  total_votes = (SELECT COUNT(*) FROM matchups WHERE
    (club_a_id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b' OR club_b_id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b')
    AND winner_id IS NOT NULL)
WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b';

-- Recalculate ELO based on actual win rate
UPDATE clubs SET
  elo_rating = CASE
    WHEN total_votes = 0 THEN 1500
    WHEN total_votes < 5 THEN 1500
    ELSE LEAST(1700, GREATEST(1300,
      ROUND(1500 + ((wins::float / NULLIF(total_votes, 0)) - 0.5) * 400)
    ))
  END
WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b';
