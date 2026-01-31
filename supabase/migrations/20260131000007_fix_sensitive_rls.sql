-- Security fix: Restrict access to sensitive tables

-- Enable RLS on banned_ips if not already
ALTER TABLE banned_ips ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies on banned_ips
DROP POLICY IF EXISTS "Anyone can read banned_ips" ON banned_ips;
DROP POLICY IF EXISTS "Public read banned_ips" ON banned_ips;

-- Only admins can read banned_ips
CREATE POLICY "Only admins can view banned_ips" ON banned_ips
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Service role can insert (for edge function)
CREATE POLICY "Service can insert banned_ips" ON banned_ips
  FOR INSERT WITH CHECK (true);

-- Enable RLS on vote_logs if not already
ALTER TABLE vote_logs ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Anyone can read vote_logs" ON vote_logs;
DROP POLICY IF EXISTS "Public read vote_logs" ON vote_logs;

-- Only admins can read vote_logs (contains IPs)
CREATE POLICY "Only admins can view vote_logs" ON vote_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Service role can insert (for edge function)
CREATE POLICY "Service can insert vote_logs" ON vote_logs
  FOR INSERT WITH CHECK (true);
