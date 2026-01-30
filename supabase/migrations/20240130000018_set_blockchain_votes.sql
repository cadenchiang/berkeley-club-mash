-- Set Blockchain votes to 132
UPDATE clubs SET
  wins = 132,
  total_votes = 132,
  elo_rating = 1600
WHERE name = 'Blockchain at Berkeley';
