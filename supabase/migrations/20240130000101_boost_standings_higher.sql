-- Boost standings higher to compensate for ongoing attack
-- Rate limit is now 10/hour but attackers got fresh quota on deploy

-- Blockchain #1 with large buffer
UPDATE clubs SET elo_rating = 2200, wins = 1100, total_votes = 1600
WHERE name = 'Blockchain';

-- AIEB #2 with buffer
UPDATE clubs SET elo_rating = 2100, wins = 1050, total_votes = 1550
WHERE name = 'AI Entrepreneurs at Berkeley';

-- Push down CMG (being used as attack vector)
UPDATE clubs SET elo_rating = 1400, wins = 550, total_votes = 1150
WHERE name = 'CMG Strategy Consulting';
