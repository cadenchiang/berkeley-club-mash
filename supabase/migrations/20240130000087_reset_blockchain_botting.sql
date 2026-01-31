-- Reset Blockchain stats after botting
UPDATE clubs SET elo_rating = 1750, wins = 677, total_votes = 1101 WHERE name = 'Blockchain';

-- Ban the suspicious sessions/fingerprints
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at) VALUES
('1395581f-7a0b-407c-b', 'fp_470a6f', 'Botting Blockchain', NOW() + INTERVAL '30 days'),
('45e7757e-ef0a-4049-8', 'fp_44cdad', 'Botting Blockchain', NOW() + INTERVAL '30 days')
ON CONFLICT DO NOTHING;
