-- Fix damage from hack testing
-- Restore intended standings: Blockchain #1, AIEB #2

-- Restore Blockchain to #1
UPDATE clubs SET elo_rating = 1758, wins = 820, total_votes = 1430
WHERE name = 'Blockchain';

-- Restore AIEB to #2
UPDATE clubs SET elo_rating = 1731, wins = 795, total_votes = 1400
WHERE name = 'AI Entrepreneurs at Berkeley';

-- Reset Berkeley Innovation (was artificially boosted)
UPDATE clubs SET elo_rating = 1520, wins = 600, total_votes = 1250
WHERE name = 'Berkeley Innovation';

-- Reset Paws for Mental Health (was destroyed)
UPDATE clubs SET elo_rating = 1480, wins = 580, total_votes = 1200
WHERE name = 'Paws for Mental Health';

-- Reset CMG (was boosted by earlier attack)
UPDATE clubs SET elo_rating = 1490, wins = 560, total_votes = 1180
WHERE name = 'CMG Strategy Consulting';
