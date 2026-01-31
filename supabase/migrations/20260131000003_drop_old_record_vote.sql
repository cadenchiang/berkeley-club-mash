-- Drop the old record_vote overload that had recaptcha_token parameter
DROP FUNCTION IF EXISTS record_vote(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT);
