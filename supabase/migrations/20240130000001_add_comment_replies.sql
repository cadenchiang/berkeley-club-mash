-- Add parent_id column for comment replies
ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES comments(id) ON DELETE CASCADE;

-- Create index for faster reply lookups
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_id);
