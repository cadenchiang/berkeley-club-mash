-- Final standings fix - Blockchain should be #1
UPDATE clubs SET elo_rating = 2600
WHERE name = 'Blockchain';

UPDATE clubs SET elo_rating = 2500
WHERE name = 'AI Entrepreneurs at Berkeley';
