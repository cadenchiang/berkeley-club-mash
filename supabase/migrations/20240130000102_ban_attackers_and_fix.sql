-- Ban attacker IPs
INSERT INTO banned_users (session_id, fingerprint, reason, expires_at)
VALUES
  ('ip_24.5.225.83', 'ip_24.5.225.83', 'Bot attack on rankings', NULL),
  ('ip_23.93.202.106', 'ip_23.93.202.106', 'Bot attack on rankings', NULL);

-- Create IP ban table for edge function to check
CREATE TABLE IF NOT EXISTS banned_ips (
  ip_address TEXT PRIMARY KEY,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- Add attacker IPs
INSERT INTO banned_ips (ip_address, reason) VALUES
  ('24.5.225.83', 'Bot attack'),
  ('23.93.202.106', 'Bot attack')
ON CONFLICT (ip_address) DO NOTHING;

-- Grant read access
GRANT SELECT ON banned_ips TO anon, authenticated;

-- Restore standings
UPDATE clubs SET elo_rating = 2500, wins = 1200, total_votes = 1700
WHERE name = 'Blockchain';

UPDATE clubs SET elo_rating = 2400, wins = 1150, total_votes = 1650
WHERE name = 'AI Entrepreneurs at Berkeley';

UPDATE clubs SET elo_rating = 1350, wins = 500, total_votes = 1100
WHERE name = 'CMG Strategy Consulting';
