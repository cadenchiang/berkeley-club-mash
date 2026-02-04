-- Allow users to delete their own comments (by session_id)

CREATE OR REPLACE FUNCTION delete_own_comment(
  p_comment_id UUID,
  p_session_id TEXT
)
RETURNS JSON AS $$
DECLARE
  v_comment_session TEXT;
BEGIN
  -- Validate session format
  IF NOT (p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_session',
      'message', 'Invalid session format.'
    );
  END IF;

  -- Get the comment's session_id
  SELECT session_id INTO v_comment_session
  FROM comments
  WHERE id = p_comment_id;

  -- Check if comment exists
  IF v_comment_session IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'not_found',
      'message', 'Comment not found.'
    );
  END IF;

  -- Check if user owns this comment
  IF v_comment_session != p_session_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'You can only delete your own comments.'
    );
  END IF;

  -- Delete the comment (and cascade to replies/votes via FK constraints)
  DELETE FROM comments WHERE id = p_comment_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Comment deleted.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
