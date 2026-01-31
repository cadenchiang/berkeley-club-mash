-- Scale down all wins to total ~35k (currently ~71k, so roughly halve)
-- Maintain win rates by scaling total_votes proportionally

UPDATE clubs SET
  wins = ROUND(wins * 0.49),
  total_votes = ROUND(total_votes * 0.49);

-- Update get_total_vote_count to return sum of wins
CREATE OR REPLACE FUNCTION get_total_vote_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(wins), 0)::INTEGER
    FROM clubs
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
