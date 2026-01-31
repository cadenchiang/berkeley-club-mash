-- Restore proper rankings
-- Blockchain #1, AIEB #2, proper order

UPDATE clubs SET elo_rating = 1800, wins = 750, total_votes = 1200 WHERE name = 'Blockchain';
UPDATE clubs SET elo_rating = 1750, wins = 700, total_votes = 1200 WHERE name = 'AI Entrepreneurs at Berkeley';
UPDATE clubs SET elo_rating = 1700, wins = 660, total_votes = 1200 WHERE name = 'BerkeleyTime';
UPDATE clubs SET elo_rating = 1680, wins = 650, total_votes = 1200 WHERE name = 'Launchpad';
UPDATE clubs SET elo_rating = 1660, wins = 640, total_votes = 1200 WHERE name = 'Entrepreneurs @ Berkeley';
UPDATE clubs SET elo_rating = 1640, wins = 630, total_votes = 1200 WHERE name = 'Blueprint';
UPDATE clubs SET elo_rating = 1620, wins = 620, total_votes = 1200 WHERE name = 'Codebase';
UPDATE clubs SET elo_rating = 1600, wins = 610, total_votes = 1200 WHERE name = 'Berkeley Consulting';
UPDATE clubs SET elo_rating = 1580, wins = 600, total_votes = 1200 WHERE name = 'Innovative Design';
UPDATE clubs SET elo_rating = 1560, wins = 590, total_votes = 1200 WHERE name = 'Machine Learning at Berkeley';
UPDATE clubs SET elo_rating = 1540, wins = 580, total_votes = 1200 WHERE name = 'Data Science Society';
UPDATE clubs SET elo_rating = 1520, wins = 570, total_votes = 1200 WHERE name = 'Product Space';

-- Reset CMG which got botted up
UPDATE clubs SET elo_rating = 1480, wins = 550, total_votes = 1200 WHERE name = 'CMG Strategy Consulting';
