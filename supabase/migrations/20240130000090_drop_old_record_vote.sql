-- Drop all old versions of record_vote
DROP FUNCTION IF EXISTS record_vote(uuid, uuid, uuid, text, text);
DROP FUNCTION IF EXISTS record_vote(uuid, uuid, uuid, text, text, text);
