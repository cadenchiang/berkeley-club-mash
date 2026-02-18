-- PURGE "Iteration N - hash" BOT COMMENTS
-- Same Feb 13 bot attack, different payload pattern: "Iteration 1234 - abcdef12"
-- ~1,891 comments matching this pattern, all with unique session_ids.

-- Step 1: Delete associated comment_votes
DELETE FROM comment_votes WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^Iteration \d+ - [0-9a-f]+$'
);

-- Step 2: Delete associated reports
DELETE FROM reports WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^Iteration \d+ - [0-9a-f]+$'
);

-- Step 3: Delete associated vote_logs
DELETE FROM vote_logs WHERE comment_id IN (
  SELECT id FROM comments
  WHERE content ~ '^Iteration \d+ - [0-9a-f]+$'
);

-- Step 4: Delete the bot comments themselves
DELETE FROM comments
WHERE content ~ '^Iteration \d+ - [0-9a-f]+$';
