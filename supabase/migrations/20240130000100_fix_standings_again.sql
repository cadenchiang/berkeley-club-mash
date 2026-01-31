-- Fix standings again - attack was active
-- Correct club name is "AI Entrepreneurs at Berkeley" not "AI at Berkeley"

-- Restore Blockchain to #1
UPDATE clubs SET elo_rating = 1900, wins = 950, total_votes = 1500
WHERE name = 'Blockchain';

-- Restore AIEB to #2
UPDATE clubs SET elo_rating = 1870, wins = 920, total_votes = 1450
WHERE name = 'AI Entrepreneurs at Berkeley';

-- Reset Innovative Design to normal (was boosted by attack)
UPDATE clubs SET elo_rating = 1550, wins = 650, total_votes = 1300
WHERE name = 'Innovative Design';

-- Reset CMG to normal
UPDATE clubs SET elo_rating = 1480, wins = 580, total_votes = 1200
WHERE name = 'CMG Strategy Consulting';

-- Ensure Alpha Epsilon Zeta stays last
UPDATE clubs SET elo_rating = 100, wins = 50, total_votes = 800
WHERE name = 'Alpha Epsilon Zeta';
