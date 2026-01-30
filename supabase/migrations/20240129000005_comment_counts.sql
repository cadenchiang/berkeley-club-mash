-- Add comment count to clubs view for rankings

/**
 * Get clubs with comment counts for the leaderboard.
 * Includes all club data plus count of visible comments.
 */
CREATE OR REPLACE FUNCTION get_clubs_with_comments(
  p_category TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  category TEXT,
  image_url TEXT,
  website TEXT,
  elo_rating INTEGER,
  total_votes INTEGER,
  wins INTEGER,
  created_at TIMESTAMPTZ,
  comment_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.description,
    c.category,
    c.image_url,
    c.website,
    c.elo_rating,
    c.total_votes,
    c.wins,
    c.created_at,
    COALESCE(
      (SELECT COUNT(*) FROM comments cm WHERE cm.club_id = c.id AND cm.is_hidden = false),
      0
    ) AS comment_count
  FROM clubs c
  WHERE
    (p_category IS NULL OR p_category = 'all' OR c.category = p_category)
    AND (p_search IS NULL OR p_search = '' OR c.name ILIKE '%' || p_search || '%')
  ORDER BY c.elo_rating DESC;
END;
$$ LANGUAGE plpgsql;

-- Create index for faster comment counting
CREATE INDEX IF NOT EXISTS idx_comments_club_visible
ON comments(club_id) WHERE is_hidden = false;
