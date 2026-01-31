-- Fix the botted comment to have reasonable votes
UPDATE comments SET upvotes = 30, downvotes = 0 WHERE content LIKE '%sanjay%bathroom%';

-- Also delete all fabricated votes for this comment
DELETE FROM comment_votes WHERE comment_id IN (
  SELECT id FROM comments WHERE content LIKE '%sanjay%bathroom%'
);
