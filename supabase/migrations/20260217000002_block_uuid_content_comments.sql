-- BLOCK UUID-FORMAT CONTENT IN COMMENTS
-- Adds a check to the add_comment function to reject comments whose
-- content is a UUID string, preventing future bot attacks of this type.

CREATE OR REPLACE FUNCTION add_comment(
  p_club_id UUID,
  p_content TEXT,
  p_session_id TEXT,
  p_parent_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_last_comment_time TIMESTAMPTZ;
  v_is_banned BOOLEAN;
  v_new_comment_id UUID;
  v_club_comment_count INTEGER;
  v_duplicate_count INTEGER;
  v_session_comment_count INTEGER;
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

  IF LENGTH(p_content) > 500 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'content_too_long',
      'message', 'Comment is too long (max 500 characters).'
    );
  END IF;

  -- ANTI-BOT: Reject UUID-format content (bot spam pattern)
  IF TRIM(p_content) ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'spam_detected',
      'message', 'This comment looks like spam.'
    );
  END IF;

  -- PROFANITY FILTER
  IF contains_profanity(p_content) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'profanity',
      'message', 'Please keep comments respectful.'
    );
  END IF;

  -- ANTI-SPAM: Rate limit - 30 second cooldown
  SELECT MAX(created_at) INTO v_last_comment_time
  FROM comments
  WHERE session_id = p_session_id;

  IF v_last_comment_time IS NOT NULL AND v_last_comment_time > NOW() - INTERVAL '30 seconds' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'cooldown',
      'message', 'Please wait 30 seconds before posting another comment.'
    );
  END IF;

  -- ANTI-SPAM: Max 5 comments per session per hour
  SELECT COUNT(*) INTO v_session_comment_count
  FROM comments
  WHERE session_id = p_session_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_session_comment_count >= 5 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'rate_limit',
      'message', 'Too many comments. Please try again later.'
    );
  END IF;

  -- ANTI-SPAM: Max 100 comments per club total
  SELECT COUNT(*) INTO v_club_comment_count
  FROM comments
  WHERE club_id = p_club_id AND is_hidden = false;

  IF v_club_comment_count >= 100 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'club_limit',
      'message', 'This club has reached the maximum number of comments.'
    );
  END IF;

  -- ANTI-SPAM: Prevent duplicate comments (same content in same club)
  SELECT COUNT(*) INTO v_duplicate_count
  FROM comments
  WHERE club_id = p_club_id
    AND UPPER(TRIM(content)) = UPPER(TRIM(p_content));

  IF v_duplicate_count > 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'duplicate',
      'message', 'This comment has already been posted.'
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
