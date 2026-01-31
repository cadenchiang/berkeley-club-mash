-- Add fingerprint tracking and rate limiting to comment votes

-- Add fingerprint column to comment_votes
ALTER TABLE comment_votes ADD COLUMN IF NOT EXISTS fingerprint TEXT;

-- Create index for fingerprint rate limiting
CREATE INDEX IF NOT EXISTS idx_comment_votes_fingerprint ON comment_votes(fingerprint, created_at);

-- Update vote_comment function with fingerprint rate limiting
CREATE OR REPLACE FUNCTION vote_comment(
  p_comment_id UUID,
  p_session_id TEXT,
  p_vote_type TEXT,
  p_fingerprint TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_current_vote TEXT;
  v_comment RECORD;
  v_fp_votes_count INTEGER;
BEGIN
  -- Validate session
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object('success', false, 'error', 'invalid_session');
  END IF;

  -- Validate vote type
  IF p_vote_type NOT IN ('up', 'down') THEN
    RETURN json_build_object('success', false, 'error', 'invalid_vote_type');
  END IF;

  -- Rate limit by fingerprint: max 20 votes per hour
  IF p_fingerprint IS NOT NULL THEN
    SELECT COUNT(*) INTO v_fp_votes_count
    FROM comment_votes
    WHERE fingerprint = p_fingerprint
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_fp_votes_count >= 20 THEN
      RETURN json_build_object('success', false, 'error', 'rate_limit', 'message', 'Too many votes. Try again later.');
    END IF;
  END IF;

  -- Get comment
  SELECT * INTO v_comment FROM comments WHERE id = p_comment_id;
  IF v_comment IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'comment_not_found');
  END IF;

  -- Get current vote
  SELECT vote_type INTO v_current_vote
  FROM comment_votes
  WHERE comment_id = p_comment_id AND session_id = p_session_id;

  IF v_current_vote = p_vote_type THEN
    -- Remove vote
    DELETE FROM comment_votes WHERE comment_id = p_comment_id AND session_id = p_session_id;
    IF p_vote_type = 'up' THEN
      UPDATE comments SET upvotes = GREATEST(0, upvotes - 1) WHERE id = p_comment_id;
    ELSE
      UPDATE comments SET downvotes = GREATEST(0, downvotes - 1) WHERE id = p_comment_id;
    END IF;
  ELSIF v_current_vote IS NOT NULL THEN
    -- Switch vote
    UPDATE comment_votes SET vote_type = p_vote_type, fingerprint = p_fingerprint WHERE comment_id = p_comment_id AND session_id = p_session_id;
    IF p_vote_type = 'up' THEN
      UPDATE comments SET upvotes = upvotes + 1, downvotes = GREATEST(0, downvotes - 1) WHERE id = p_comment_id;
    ELSE
      UPDATE comments SET downvotes = downvotes + 1, upvotes = GREATEST(0, upvotes - 1) WHERE id = p_comment_id;
    END IF;
  ELSE
    -- New vote
    INSERT INTO comment_votes (comment_id, session_id, vote_type, fingerprint) VALUES (p_comment_id, p_session_id, p_vote_type, p_fingerprint);
    IF p_vote_type = 'up' THEN
      UPDATE comments SET upvotes = upvotes + 1 WHERE id = p_comment_id;
    ELSE
      UPDATE comments SET downvotes = downvotes + 1 WHERE id = p_comment_id;
    END IF;
  END IF;

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reset that botted comment's upvotes
UPDATE comments SET upvotes = 12 WHERE upvotes > 1000;

-- Delete excess votes from comment_votes for botted comments
DELETE FROM comment_votes
WHERE comment_id IN (SELECT id FROM comments WHERE content LIKE '%sanjay%bathroom%')
  AND id NOT IN (
    SELECT id FROM comment_votes
    WHERE comment_id IN (SELECT id FROM comments WHERE content LIKE '%sanjay%bathroom%')
    ORDER BY created_at DESC
    LIMIT 12
  );
