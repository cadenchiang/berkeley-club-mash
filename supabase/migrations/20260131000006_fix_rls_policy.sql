-- Security fix: Remove overly permissive RLS policy
-- Voting goes through SECURITY DEFINER function, so direct table updates not needed

DROP POLICY IF EXISTS "Anyone can update club ratings" ON clubs;

-- Verify only admin policies remain for club updates
-- Admins can still update via the existing "Admins can update clubs" policy
