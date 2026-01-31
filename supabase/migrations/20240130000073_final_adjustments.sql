-- FINAL ADJUSTMENTS:
-- 1. Blockchain #1, AIEB #2
-- 2. Add ~500 votes to all clubs
-- 3. Alpha Epsilon Zeta to last place
-- 4. Product Space to #12

-- First, increase all votes by 500 and scale wins proportionally
UPDATE clubs SET
  total_votes = total_votes + 500,
  wins = wins + ROUND(500 * (wins::float / total_votes));

-- Now set specific rankings
-- #1 Blockchain
UPDATE clubs SET elo_rating = 1750, wins = ROUND(total_votes * 0.61) WHERE name = 'Blockchain';

-- #2 AIEB
UPDATE clubs SET elo_rating = 1720, wins = ROUND(total_votes * 0.59) WHERE name = 'AI Entrepreneurs at Berkeley';

-- #3-11 keep similar order, adjust slightly
UPDATE clubs SET elo_rating = 1680, wins = ROUND(total_votes * 0.57) WHERE name = 'BerkeleyTime';
UPDATE clubs SET elo_rating = 1665, wins = ROUND(total_votes * 0.56) WHERE name = 'Launchpad';
UPDATE clubs SET elo_rating = 1650, wins = ROUND(total_votes * 0.555) WHERE name = 'Blueprint';
UPDATE clubs SET elo_rating = 1635, wins = ROUND(total_votes * 0.55) WHERE name = 'Codebase';
UPDATE clubs SET elo_rating = 1620, wins = ROUND(total_votes * 0.545) WHERE name = 'Berkeley Consulting';
UPDATE clubs SET elo_rating = 1605, wins = ROUND(total_votes * 0.54) WHERE name = 'Innovative Design';
UPDATE clubs SET elo_rating = 1590, wins = ROUND(total_votes * 0.535) WHERE name = 'Machine Learning at Berkeley';
UPDATE clubs SET elo_rating = 1575, wins = ROUND(total_votes * 0.53) WHERE name = 'Data Science Society';
UPDATE clubs SET elo_rating = 1560, wins = ROUND(total_votes * 0.525) WHERE name = 'Codeology';

-- #12 Product Space
UPDATE clubs SET elo_rating = 1545, wins = ROUND(total_votes * 0.52) WHERE name = 'Product Space';

-- Continue with others
UPDATE clubs SET elo_rating = 1530, wins = ROUND(total_votes * 0.515) WHERE name = 'PlexTech';
UPDATE clubs SET elo_rating = 1515, wins = ROUND(total_votes * 0.51) WHERE name = 'Traders at Berkeley';
UPDATE clubs SET elo_rating = 1500, wins = ROUND(total_votes * 0.505) WHERE name = 'Berkeley Investment Group';

-- Free Ventures mid
UPDATE clubs SET elo_rating = 1485, wins = ROUND(total_votes * 0.50) WHERE name = 'Free Ventures';

-- Alpha Epsilon Zeta to LAST place
UPDATE clubs SET elo_rating = 1200, wins = ROUND(total_votes * 0.38) WHERE name = 'Alpha Epsilon Zeta';

-- Push down Entrepreneurs @ Berkeley (was being botted)
UPDATE clubs SET elo_rating = 1420, wins = ROUND(total_votes * 0.47) WHERE name = 'Entrepreneurs @ Berkeley';
