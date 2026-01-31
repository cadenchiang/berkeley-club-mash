-- RANDOMIZE WINS: Make win counts look natural with more variance
-- Each club gets unique random wins based on their ELO tier

UPDATE clubs SET
  wins = CASE
    WHEN elo_rating >= 1740 THEN 620 + floor(random() * 80)::int   -- 620-700
    WHEN elo_rating >= 1700 THEN 580 + floor(random() * 70)::int   -- 580-650
    WHEN elo_rating >= 1650 THEN 540 + floor(random() * 60)::int   -- 540-600
    WHEN elo_rating >= 1600 THEN 500 + floor(random() * 55)::int   -- 500-555
    WHEN elo_rating >= 1550 THEN 460 + floor(random() * 50)::int   -- 460-510
    WHEN elo_rating >= 1520 THEN 420 + floor(random() * 50)::int   -- 420-470
    WHEN elo_rating >= 1500 THEN 380 + floor(random() * 50)::int   -- 380-430
    WHEN elo_rating >= 1450 THEN 340 + floor(random() * 50)::int   -- 340-390
    WHEN elo_rating >= 1400 THEN 300 + floor(random() * 45)::int   -- 300-345
    ELSE 200 + floor(random() * 40)::int   -- 200-240 (bottom)
  END;

-- Set total_votes based on wins to get appropriate win rates
UPDATE clubs SET
  total_votes = CASE
    WHEN elo_rating >= 1740 THEN round(wins / (0.59 + random() * 0.03))  -- ~59-62% win rate
    WHEN elo_rating >= 1700 THEN round(wins / (0.56 + random() * 0.03))  -- ~56-59%
    WHEN elo_rating >= 1650 THEN round(wins / (0.53 + random() * 0.03))  -- ~53-56%
    WHEN elo_rating >= 1600 THEN round(wins / (0.51 + random() * 0.03))  -- ~51-54%
    WHEN elo_rating >= 1550 THEN round(wins / (0.49 + random() * 0.03))  -- ~49-52%
    WHEN elo_rating >= 1520 THEN round(wins / (0.48 + random() * 0.03))  -- ~48-51%
    WHEN elo_rating >= 1500 THEN round(wins / (0.47 + random() * 0.03))  -- ~47-50%
    WHEN elo_rating >= 1450 THEN round(wins / (0.45 + random() * 0.03))  -- ~45-48%
    WHEN elo_rating >= 1400 THEN round(wins / (0.43 + random() * 0.03))  -- ~43-46%
    ELSE round(wins / (0.36 + random() * 0.04))  -- ~36-40% (bottom)
  END;
