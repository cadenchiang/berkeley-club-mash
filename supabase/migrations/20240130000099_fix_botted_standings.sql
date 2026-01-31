-- Fix botted standings: CMG was massively upvoted, Blockchain was massively downvoted
-- Reset to intended standings: Blockchain #1, AIEB #2, Alpha Epsilon Zeta last

-- Reset CMG to normal levels
UPDATE clubs SET elo_rating = 1480, wins = 580, total_votes = 1200
WHERE name = 'CMG Strategy Consulting';

-- Restore Blockchain to #1
UPDATE clubs SET elo_rating = 1850, wins = 920, total_votes = 1450
WHERE name = 'Blockchain';

-- Restore AIEB to #2
UPDATE clubs SET elo_rating = 1820, wins = 890, total_votes = 1420
WHERE name = 'AI at Berkeley';

-- Ensure Alpha Epsilon Zeta is last
UPDATE clubs SET elo_rating = 100, wins = 50, total_votes = 800
WHERE name = 'Alpha Epsilon Zeta';

-- Also normalize any other clubs that may have been affected
-- Reset any club with abnormally high ELO (>2000) back to reasonable levels
UPDATE clubs SET elo_rating = 1500, wins = GREATEST(wins, 550), total_votes = GREATEST(total_votes, 1150)
WHERE elo_rating > 2000 AND name NOT IN ('Blockchain', 'AI at Berkeley');

-- Reset any club with abnormally low ELO (<200) except Alpha Epsilon Zeta
UPDATE clubs SET elo_rating = 1400, wins = GREATEST(wins, 500), total_votes = GREATEST(total_votes, 1100)
WHERE elo_rating < 200 AND name != 'Alpha Epsilon Zeta';
