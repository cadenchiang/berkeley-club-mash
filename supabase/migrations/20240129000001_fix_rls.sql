-- Fix RLS policies to allow club inserts without admin recursion

-- Drop the problematic admin-only insert policy
DROP POLICY IF EXISTS "Admins can insert clubs" ON clubs;

-- Allow anyone to insert clubs (for now, can be tightened later)
CREATE POLICY "Anyone can insert clubs" ON clubs
  FOR INSERT WITH CHECK (true);
