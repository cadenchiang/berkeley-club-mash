-- Reset clubs that were manipulated by bots
UPDATE clubs SET elo_rating = 1500, wins = 50, total_votes = 100 WHERE name = 'Blockchain at Berkeley';
UPDATE clubs SET elo_rating = 1500, wins = 50, total_votes = 100 WHERE name = 'Mobile Developers of Berkeley';
