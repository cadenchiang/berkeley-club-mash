-- Phase 5: Set Blockchain #1, Entrepreneurs @ Berkeley #2, AI Entrepreneurs at Berkeley #3
-- with realistic vote distributions matching the ~2,450 average across all clubs.

-- Blockchain -> #1: ELO 1712, 2455 total_votes, 1318 wins (53.7%)
UPDATE clubs SET elo_rating = 1712, wins = 1318, total_votes = 2455
WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'; -- Blockchain

-- Entrepreneurs @ Berkeley -> #2: ELO 1698, 2480 total_votes, 1342 wins (54.1%)
UPDATE clubs SET elo_rating = 1698, wins = 1342, total_votes = 2480
WHERE id = '18db0409-32b9-4e32-9970-1068b9134f03'; -- Entrepreneurs @ Berkeley

-- AI Entrepreneurs at Berkeley -> #3: ELO 1690, 2458 total_votes, 1328 wins (54.0%)
UPDATE clubs SET elo_rating = 1690, wins = 1328, total_votes = 2458
WHERE id = 'c3221797-d476-459b-8885-ce10be328f05'; -- AI Entrepreneurs at Berkeley
