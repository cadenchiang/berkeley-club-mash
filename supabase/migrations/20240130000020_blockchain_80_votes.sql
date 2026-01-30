-- Set Blockchain to 80 votes, keep first place (above 1635)
UPDATE clubs SET
  wins = 80,
  total_votes = 80,
  elo_rating = 1680
WHERE name = 'Blockchain at Berkeley';
