-- PURGE UUID-CONTENT BOT COMMENTS
-- Bot attack on ~2026-02-13/14 flooded the comments table with ~17,000+
-- comments whose content is a UUID string (e.g. "68b44656-eb37-4f99-8178-55dfa3d50426").
-- All have 0 upvotes/downvotes and unique session_ids.

-- Step 1: Delete associated comment_votes
DELETE FROM comment_votes WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
);

-- Step 2: Delete associated reports
DELETE FROM reports WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
);

-- Step 3: Delete associated vote_logs
DELETE FROM vote_logs WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
);

-- Step 4: Delete the bot comments themselves
DELETE FROM comments
WHERE content ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
