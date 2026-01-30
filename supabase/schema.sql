-- Berkeley ClubMash Database Schema

-- Clubs table
CREATE TABLE clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'other',
  image_url TEXT,
  website TEXT,
  elo_rating INTEGER NOT NULL DEFAULT 1500,
  total_votes INTEGER NOT NULL DEFAULT 0,
  wins INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for sorting by ELO
CREATE INDEX idx_clubs_elo ON clubs(elo_rating DESC);

-- Matchups table (voting history)
CREATE TABLE matchups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_a_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  club_b_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  winner_id UUID REFERENCES clubs(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for counting today's votes
CREATE INDEX idx_matchups_created ON matchups(created_at);

-- Comments table
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  upvotes INTEGER NOT NULL DEFAULT 0,
  downvotes INTEGER NOT NULL DEFAULT 0,
  is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for fetching comments by club
CREATE INDEX idx_comments_club ON comments(club_id, created_at DESC);

-- Comment votes table (track who voted on what)
CREATE TABLE comment_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  vote_type TEXT NOT NULL CHECK (vote_type IN ('up', 'down')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(comment_id, session_id)
);

-- Reports table
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Admins table (links to Supabase Auth users)
CREATE TABLE admins (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Row Level Security Policies

-- Enable RLS on all tables
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE matchups ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- Clubs: Anyone can read, only admins can modify
CREATE POLICY "Clubs are viewable by everyone" ON clubs
  FOR SELECT USING (true);

CREATE POLICY "Admins can insert clubs" ON clubs
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

CREATE POLICY "Admins can update clubs" ON clubs
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

CREATE POLICY "Admins can delete clubs" ON clubs
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Allow anonymous updates to ELO ratings (for voting)
CREATE POLICY "Anyone can update club ratings" ON clubs
  FOR UPDATE USING (true)
  WITH CHECK (true);

-- Matchups: Anyone can read and insert
CREATE POLICY "Matchups are viewable by everyone" ON matchups
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create matchups" ON matchups
  FOR INSERT WITH CHECK (true);

-- Comments: Anyone can read visible comments, anyone can insert
CREATE POLICY "Visible comments are viewable by everyone" ON comments
  FOR SELECT USING (is_hidden = false OR EXISTS (SELECT 1 FROM admins WHERE id = auth.uid()));

CREATE POLICY "Anyone can create comments" ON comments
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can update comments" ON comments
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Comment votes: Anyone can read and insert
CREATE POLICY "Comment votes are viewable by everyone" ON comment_votes
  FOR SELECT USING (true);

CREATE POLICY "Anyone can vote on comments" ON comment_votes
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own votes" ON comment_votes
  FOR UPDATE USING (true);

-- Reports: Anyone can create, only admins can view and update
CREATE POLICY "Anyone can create reports" ON reports
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view reports" ON reports
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

CREATE POLICY "Admins can update reports" ON reports
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Admins: Only admins can view admin list
CREATE POLICY "Admins can view admin list" ON admins
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- Function to get a random pair of clubs
CREATE OR REPLACE FUNCTION get_random_pair()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  category TEXT,
  image_url TEXT,
  elo_rating INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.name, c.description, c.category, c.image_url, c.elo_rating
  FROM clubs c
  ORDER BY RANDOM()
  LIMIT 2;
END;
$$ LANGUAGE plpgsql;

-- Function to count today's votes
CREATE OR REPLACE FUNCTION get_today_vote_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM matchups
    WHERE created_at >= CURRENT_DATE
    AND winner_id IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql;

-- Sample data (10 Berkeley clubs)
INSERT INTO clubs (name, description, category) VALUES
  ('Berkeley Consulting', 'Premier undergraduate consulting organization providing strategic solutions', 'professional'),
  ('Cal Hiking Club', 'Explore the beautiful trails around the Bay Area with fellow Bears', 'sports'),
  ('Data Science Society', 'Learn and apply data science skills through workshops and projects', 'academic'),
  ('Cal Bhangra', 'Competitive Bhangra dance team representing UC Berkeley nationwide', 'cultural'),
  ('Blockchain at Berkeley', 'Leading university blockchain organization focused on education and consulting', 'academic'),
  ('Engineers Without Borders', 'Designing sustainable engineering solutions for developing communities', 'professional'),
  ('Cal Comedy', 'The only improv and sketch comedy group on campus', 'social'),
  ('Society of Women Engineers', 'Supporting women in engineering through networking and professional development', 'professional'),
  ('Cal Quidditch', 'Competitive quidditch team - yes, the sport from Harry Potter', 'sports'),
  ('Photography Club', 'Capture the beauty of Berkeley through the lens with fellow photographers', 'social'),
  ('Model United Nations', 'Debate global issues and represent countries in simulated UN conferences', 'academic'),
  ('Cal Running Club', 'From casual joggers to competitive racers, all are welcome', 'sports'),
  ('Asian American Association', 'Celebrating Asian American culture and building community on campus', 'cultural'),
  ('Debate Society', 'Sharpen your argumentation skills through competitive parliamentary debate', 'academic'),
  ('Environmental Club', 'Advocating for sustainability and environmental justice on campus', 'social');
