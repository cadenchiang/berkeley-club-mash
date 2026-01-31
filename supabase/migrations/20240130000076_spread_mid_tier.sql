-- SPREAD MID-TIER CLUBS: Give unique ELOs and varied win rates to clubs at 1500 ELO
-- This makes the rankings look more natural with real variance

-- Step 1: Assign random unique ELO values to mid-tier clubs (currently at 1500)
-- Spread them between 1350 and 1520 with random offsets
UPDATE clubs SET
  elo_rating = 1350 + floor(random() * 170)::int
WHERE elo_rating = 1500;

-- Step 2: Now recalculate wins based on new ELO with more variance
-- Each tier gets a different win rate range
UPDATE clubs SET
  wins = CASE
    WHEN elo_rating >= 1740 THEN round(total_votes * (0.59 + random() * 0.04))  -- 59-63%
    WHEN elo_rating >= 1700 THEN round(total_votes * (0.55 + random() * 0.04))  -- 55-59%
    WHEN elo_rating >= 1650 THEN round(total_votes * (0.52 + random() * 0.04))  -- 52-56%
    WHEN elo_rating >= 1600 THEN round(total_votes * (0.50 + random() * 0.04))  -- 50-54%
    WHEN elo_rating >= 1550 THEN round(total_votes * (0.48 + random() * 0.04))  -- 48-52%
    WHEN elo_rating >= 1500 THEN round(total_votes * (0.46 + random() * 0.05))  -- 46-51%
    WHEN elo_rating >= 1450 THEN round(total_votes * (0.44 + random() * 0.05))  -- 44-49%
    WHEN elo_rating >= 1400 THEN round(total_votes * (0.42 + random() * 0.05))  -- 42-47%
    WHEN elo_rating >= 1350 THEN round(total_votes * (0.40 + random() * 0.05))  -- 40-45%
    WHEN elo_rating >= 1300 THEN round(total_votes * (0.38 + random() * 0.05))  -- 38-43%
    WHEN elo_rating >= 1250 THEN round(total_votes * (0.36 + random() * 0.05))  -- 36-41%
    ELSE round(total_votes * (0.34 + random() * 0.05))  -- 34-39% (bottom tier)
  END;

-- Step 3: Preserve the top clubs we manually set
UPDATE clubs SET elo_rating = 1750, wins = round(total_votes * 0.61) WHERE name = 'Blockchain';
UPDATE clubs SET elo_rating = 1720, wins = round(total_votes * 0.58) WHERE name = 'AI Entrepreneurs at Berkeley';
UPDATE clubs SET elo_rating = 1680, wins = round(total_votes * 0.55) WHERE name = 'BerkeleyTime';
UPDATE clubs SET elo_rating = 1665, wins = round(total_votes * 0.54) WHERE name = 'Launchpad';
UPDATE clubs SET elo_rating = 1650, wins = round(total_votes * 0.53) WHERE name = 'Blueprint';
UPDATE clubs SET elo_rating = 1635, wins = round(total_votes * 0.52) WHERE name = 'Codebase';
UPDATE clubs SET elo_rating = 1620, wins = round(total_votes * 0.515) WHERE name = 'Berkeley Consulting';
UPDATE clubs SET elo_rating = 1605, wins = round(total_votes * 0.51) WHERE name = 'Innovative Design';
UPDATE clubs SET elo_rating = 1590, wins = round(total_votes * 0.505) WHERE name = 'Machine Learning at Berkeley';
UPDATE clubs SET elo_rating = 1575, wins = round(total_votes * 0.50) WHERE name = 'Data Science Society';
UPDATE clubs SET elo_rating = 1560, wins = round(total_votes * 0.495) WHERE name = 'Codeology';
UPDATE clubs SET elo_rating = 1545, wins = round(total_votes * 0.49) WHERE name = 'Product Space';

-- Keep Alpha Epsilon Zeta at last place
UPDATE clubs SET elo_rating = 1200, wins = round(total_votes * 0.37) WHERE name = 'Alpha Epsilon Zeta';

-- Keep Free Ventures mid-tier
UPDATE clubs SET elo_rating = 1510, wins = round(total_votes * 0.505) WHERE name = 'Free Ventures';

-- Push down Entrepreneurs @ Berkeley (was being botted)
UPDATE clubs SET elo_rating = 1420, wins = round(total_votes * 0.46) WHERE name = 'Entrepreneurs @ Berkeley';
