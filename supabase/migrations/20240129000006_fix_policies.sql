-- Fix infinite recursion in admins policy and simplify RLS

-- Drop problematic policies
DROP POLICY IF EXISTS "Admins can view admin list" ON admins;
DROP POLICY IF EXISTS "Admins can insert clubs" ON clubs;
DROP POLICY IF EXISTS "Admins can update clubs" ON clubs;
DROP POLICY IF EXISTS "Admins can delete clubs" ON clubs;
DROP POLICY IF EXISTS "Anyone can insert clubs" ON clubs;

-- Simple admin policy - just check if user exists in admins table directly
CREATE POLICY "Anyone can view admins" ON admins
  FOR SELECT USING (true);

-- Keep clubs open for now (development)
CREATE POLICY "Anyone can insert clubs" ON clubs
  FOR INSERT WITH CHECK (true);

-- Fix the get_clubs_with_comments function to avoid RLS issues
DROP FUNCTION IF EXISTS get_clubs_with_comments(TEXT, TEXT);

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
)
SECURITY DEFINER
AS $$
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
    (SELECT COUNT(*) FROM comments cm WHERE cm.club_id = c.id AND cm.is_hidden = false)::BIGINT AS comment_count
  FROM clubs c
  WHERE
    (p_category IS NULL OR p_category = 'all' OR p_category = '' OR c.category = p_category)
    AND (p_search IS NULL OR p_search = '' OR c.name ILIKE '%' || p_search || '%')
  ORDER BY c.elo_rating DESC;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_clubs_with_comments(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_clubs_with_comments(TEXT, TEXT) TO authenticated;
