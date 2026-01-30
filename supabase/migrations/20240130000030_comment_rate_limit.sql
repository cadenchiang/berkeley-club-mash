-- ADD COMMENT RATE LIMITING
-- Create secure function for adding comments with rate limits

-- First add session_id column to comments if not exists
ALTER TABLE comments ADD COLUMN IF NOT EXISTS session_id TEXT;

-- Create index for rate limit queries
CREATE INDEX IF NOT EXISTS idx_comments_session_created ON comments(session_id, created_at);

-- Create secure add_comment function
CREATE OR REPLACE FUNCTION add_comment(
  p_club_id UUID,
  p_content TEXT,
  p_session_id TEXT,
  p_parent_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_recent_comments INTEGER;
  v_last_comment_time TIMESTAMPTZ;
  v_is_banned BOOLEAN;
  v_new_comment_id UUID;
BEGIN
  -- Validate session format (must be UUID)
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- Check if banned
  SELECT EXISTS(
    SELECT 1 FROM banned_users
    WHERE session_id = p_session_id
      AND (expires_at IS NULL OR expires_at > NOW())
  ) INTO v_is_banned;

  IF v_is_banned THEN
    RETURN json_build_object(
      'success', false,
      'error', 'banned',
      'message', 'Your access has been restricted.'
    );
  END IF;

  -- Validate content
  IF p_content IS NULL OR LENGTH(TRIM(p_content)) < 1 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_content',
      'message', 'Comment cannot be empty.'
    );
  END IF;

  IF LENGTH(p_content) > 1000 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'content_too_long',
      'message', 'Comment is too long (max 1000 characters).'
    );
  END IF;

  -- RATE LIMIT: Max 1 comment per 30 seconds
  SELECT MAX(created_at) INTO v_last_comment_time
  FROM comments
  WHERE session_id = p_session_id;

  IF v_last_comment_time IS NOT NULL AND v_last_comment_time > NOW() - INTERVAL '30 seconds' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'cooldown',
      'message', 'Please wait before posting another comment.'
    );
  END IF;

  -- RATE LIMIT: Max 10 comments per hour per session
  SELECT COUNT(*) INTO v_recent_comments
  FROM comments
  WHERE session_id = p_session_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_recent_comments >= 10 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'rate_limit',
      'message', 'Too many comments. Please try again later.'
    );
  END IF;

  -- Validate club exists
  IF NOT EXISTS (SELECT 1 FROM clubs WHERE id = p_club_id) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_club',
      'message', 'Club not found.'
    );
  END IF;

  -- Validate parent comment if provided
  IF p_parent_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM comments WHERE id = p_parent_id) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_parent',
      'message', 'Parent comment not found.'
    );
  END IF;

  -- Insert the comment
  INSERT INTO comments (club_id, content, parent_id, session_id)
  VALUES (p_club_id, TRIM(p_content), p_parent_id, p_session_id)
  RETURNING id INTO v_new_comment_id;

  RETURN json_build_object(
    'success', true,
    'comment_id', v_new_comment_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Lock down comments table - only SELECT allowed
REVOKE ALL ON comments FROM anon;
REVOKE ALL ON comments FROM authenticated;
GRANT SELECT ON comments TO anon;
GRANT SELECT ON comments TO authenticated;

-- Also lock down comment_votes and reports
REVOKE ALL ON comment_votes FROM anon;
REVOKE ALL ON comment_votes FROM authenticated;
GRANT SELECT ON comment_votes TO anon;
GRANT SELECT ON comment_votes TO authenticated;

REVOKE ALL ON reports FROM anon;
REVOKE ALL ON reports FROM authenticated;

-- Create secure function for voting on comments
CREATE OR REPLACE FUNCTION vote_comment(
  p_comment_id UUID,
  p_session_id TEXT,
  p_vote_type TEXT
)
RETURNS JSON AS $$
DECLARE
  v_current_vote TEXT;
  v_comment RECORD;
BEGIN
  -- Validate session
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object('success', false, 'error', 'invalid_session');
  END IF;

  -- Validate vote type
  IF p_vote_type NOT IN ('up', 'down') THEN
    RETURN json_build_object('success', false, 'error', 'invalid_vote_type');
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
    UPDATE comment_votes SET vote_type = p_vote_type WHERE comment_id = p_comment_id AND session_id = p_session_id;
    IF p_vote_type = 'up' THEN
      UPDATE comments SET upvotes = upvotes + 1, downvotes = GREATEST(0, downvotes - 1) WHERE id = p_comment_id;
    ELSE
      UPDATE comments SET downvotes = downvotes + 1, upvotes = GREATEST(0, upvotes - 1) WHERE id = p_comment_id;
    END IF;
  ELSE
    -- New vote
    INSERT INTO comment_votes (comment_id, session_id, vote_type) VALUES (p_comment_id, p_session_id, p_vote_type);
    IF p_vote_type = 'up' THEN
      UPDATE comments SET upvotes = upvotes + 1 WHERE id = p_comment_id;
    ELSE
      UPDATE comments SET downvotes = downvotes + 1 WHERE id = p_comment_id;
    END IF;
  END IF;

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create secure function for reporting comments
CREATE OR REPLACE FUNCTION report_comment(
  p_comment_id UUID,
  p_reason TEXT,
  p_session_id TEXT
)
RETURNS JSON AS $$
BEGIN
  -- Validate
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object('success', false, 'error', 'invalid_session');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM comments WHERE id = p_comment_id) THEN
    RETURN json_build_object('success', false, 'error', 'comment_not_found');
  END IF;

  INSERT INTO reports (comment_id, reason) VALUES (p_comment_id, TRIM(p_reason));

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
