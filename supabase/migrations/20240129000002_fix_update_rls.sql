-- Fix update RLS policy to avoid admin recursion
DROP POLICY IF EXISTS "Admins can update clubs" ON clubs;
DROP POLICY IF EXISTS "Anyone can update club ratings" ON clubs;

-- Allow anyone to update clubs (for now)
CREATE POLICY "Anyone can update clubs" ON clubs
  FOR UPDATE USING (true) WITH CHECK (true);
