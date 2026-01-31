-- Create vote_logs table to track IPs for abuse detection
CREATE TABLE IF NOT EXISTS vote_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL,
  comment_id UUID REFERENCES comments(id),
  session_id TEXT,
  fingerprint TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for IP-based queries
CREATE INDEX IF NOT EXISTS idx_vote_logs_ip ON vote_logs(ip_address, created_at);

-- Clean up old logs after 7 days (run manually or via cron)
-- DELETE FROM vote_logs WHERE created_at < NOW() - INTERVAL '7 days';
