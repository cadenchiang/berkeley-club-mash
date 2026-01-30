-- Fix delete RLS policy
DROP POLICY IF EXISTS "Admins can delete clubs" ON clubs;

-- Allow anyone to delete clubs (for now)
CREATE POLICY "Anyone can delete clubs" ON clubs
  FOR DELETE USING (true);
