-- Set Blockchain at Berkeley to #1 with realistic stats
UPDATE clubs SET
  elo_rating = 1650,
  wins = 70,
  total_votes = 115
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';
