-- Storage cleanup: remove dead data and optimize tables.

-- 1. Clear vote_logs (currently 0 rows but table exists with overhead)
TRUNCATE vote_logs;

-- 2. Clear rate limit tracking tables (ephemeral data, not needed long-term)
TRUNCATE vote_cooldowns;
TRUNCATE ip_rate_limits;

-- 3. Drop unused indexes on matchups (reduces index bloat)
-- Keep only the essential ones
DROP INDEX IF EXISTS idx_matchups_ip_created;
DROP INDEX IF EXISTS idx_matchups_fingerprint_time;

-- 4. Optimize column types on matchups for space efficiency
ALTER TABLE matchups ALTER COLUMN ip_address TYPE inet USING ip_address::inet;

-- 5. Analyze tables so planner uses accurate stats
ANALYZE matchups;
ANALYZE clubs;
ANALYZE comments;
ANALYZE comment_votes;
