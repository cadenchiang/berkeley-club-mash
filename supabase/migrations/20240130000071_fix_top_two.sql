-- Fix AIEB and Blockchain to be #1 and #2
UPDATE clubs SET elo_rating = 1750, wins = 340, total_votes = 560 WHERE name = 'AI Entrepreneurs at Berkeley';
UPDATE clubs SET elo_rating = 1710, wins = 325, total_votes = 560 WHERE name = 'Blockchain';
