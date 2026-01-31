-- Complete RLS policies for all sensitive tables

-- banned_ips: Only admins can delete
CREATE POLICY "Only admins can delete banned_ips" ON banned_ips
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM admins WHERE id = auth.uid())
  );

-- vote_logs: No delete allowed (audit trail)
-- No DELETE policy = default deny

-- matchups: Remove fingerprint from public view (privacy)
-- Actually, fingerprints are hashed and session_ids are random UUIDs - not PII
-- Keep as is for vote history transparency
