-- Add server-side profanity filter to prevent bypass of client-side filter

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
  v_lower_content TEXT;
  v_blocked_words TEXT[] := ARRAY[
    'nigger', 'nigga', 'faggot', 'fag', 'retard', 'kike', 
    'chink', 'spic', 'wetback', 'cunt', 'n1gger', 'f4ggot',
    'n1gga', 'f4g', 'r3tard', 'k1ke', 'ch1nk', 'sp1c'
  ];
  v_word TEXT;
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

  -- SERVER-SIDE PROFANITY FILTER
  v_lower_content := LOWER(p_content);
  FOREACH v_word IN ARRAY v_blocked_words LOOP
    IF v_lower_content LIKE '%' || v_word || '%' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'profanity',
        'message', 'Please keep comments respectful.'
      );
    END IF;
  END LOOP;

  -- RATE LIMIT: 10 second cooldown only
  SELECT MAX(created_at) INTO v_last_comment_time
  FROM comments
  WHERE session_id = p_session_id;

  IF v_last_comment_time IS NOT NULL AND v_last_comment_time > NOW() - INTERVAL '10 seconds' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'cooldown',
      'message', 'Please wait before posting another comment.'
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
