-- COMPLETE RESET: Set all clubs to exact desired values
-- AIEB #1, Blockchain #2, Free Ventures mid, sensible win rates

-- First reset everyone to baseline
UPDATE clubs SET elo_rating = 1500, wins = 280, total_votes = 560;

-- Now set specific clubs
UPDATE clubs SET elo_rating = 1720, wins = 336, total_votes = 560 WHERE name = 'AI Entrepreneurs at Berkeley';
UPDATE clubs SET elo_rating = 1690, wins = 325, total_votes = 560 WHERE name = 'Blockchain';
UPDATE clubs SET elo_rating = 1660, wins = 314, total_votes = 560 WHERE name = 'BerkeleyTime';
UPDATE clubs SET elo_rating = 1650, wins = 311, total_votes = 560 WHERE name = 'Launchpad';
UPDATE clubs SET elo_rating = 1640, wins = 308, total_votes = 560 WHERE name = 'Blueprint';
UPDATE clubs SET elo_rating = 1630, wins = 306, total_votes = 560 WHERE name = 'Codebase';
UPDATE clubs SET elo_rating = 1620, wins = 303, total_votes = 560 WHERE name = 'Berkeley Consulting';
UPDATE clubs SET elo_rating = 1610, wins = 300, total_votes = 560 WHERE name = 'Innovative Design';
UPDATE clubs SET elo_rating = 1600, wins = 297, total_votes = 560 WHERE name = 'Machine Learning at Berkeley';
UPDATE clubs SET elo_rating = 1590, wins = 294, total_votes = 560 WHERE name = 'Data Science Society';
UPDATE clubs SET elo_rating = 1580, wins = 292, total_votes = 560 WHERE name = 'Codeology';
UPDATE clubs SET elo_rating = 1570, wins = 289, total_votes = 560 WHERE name = 'PlexTech';
UPDATE clubs SET elo_rating = 1560, wins = 286, total_votes = 560 WHERE name = 'Traders at Berkeley';
UPDATE clubs SET elo_rating = 1550, wins = 283, total_votes = 560 WHERE name = 'Berkeley Investment Group';
UPDATE clubs SET elo_rating = 1540, wins = 280, total_votes = 560 WHERE name = 'Capital Investments at Berkeley';
UPDATE clubs SET elo_rating = 1530, wins = 278, total_votes = 560 WHERE name = 'Net Impact Berkeley';
UPDATE clubs SET elo_rating = 1520, wins = 275, total_votes = 560 WHERE name = 'Free Ventures';
UPDATE clubs SET elo_rating = 1510, wins = 272, total_votes = 560 WHERE name = 'The Berkeley Forum';
UPDATE clubs SET elo_rating = 1505, wins = 270, total_votes = 560 WHERE name = 'Women on Wall Street';
UPDATE clubs SET elo_rating = 1500, wins = 268, total_votes = 560 WHERE name = 'Berkeley Business Society';

-- Push Entrepreneurs @ Berkeley down (it was being botted)
UPDATE clubs SET elo_rating = 1450, wins = 258, total_votes = 560 WHERE name = 'Entrepreneurs @ Berkeley';
