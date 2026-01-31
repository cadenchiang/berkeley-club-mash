-- Make standings look organic - gradual distribution from top
-- Current pack is around 1520-1685, so top should be ~1750-1720

UPDATE clubs SET elo_rating = 1758, wins = 815, total_votes = 1420
WHERE name = 'Blockchain';

UPDATE clubs SET elo_rating = 1731, wins = 790, total_votes = 1395
WHERE name = 'AI Entrepreneurs at Berkeley';

-- Innovative Design stays roughly where it is as #3
UPDATE clubs SET elo_rating = 1698, wins = 680, total_votes = 1340
WHERE name = 'Innovative Design';
