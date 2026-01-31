-- DIRECT FIX: Set ELO, wins, and votes directly to produce sensible rankings
-- Higher ELO = higher win rate (as it should be)
--
-- Ranking: AIEB #1, Blockchain #2, then spread others logically
-- Win rates: Top clubs ~58-62%, middle ~50-52%, bottom ~45-48%

-- Don't touch matchups, just set the display stats directly
UPDATE clubs SET
  elo_rating = CASE name
    WHEN 'AI Entrepreneurs at Berkeley' THEN 1720
    WHEN 'Blockchain' THEN 1680
    WHEN 'Free Ventures' THEN 1520
    WHEN 'BerkeleyTime' THEN 1640
    WHEN 'Launchpad' THEN 1630
    WHEN 'Blueprint' THEN 1620
    WHEN 'Codebase' THEN 1610
    WHEN 'Berkeley Consulting' THEN 1600
    WHEN 'Innovative Design' THEN 1590
    WHEN 'Machine Learning at Berkeley' THEN 1580
    WHEN 'Data Science Society' THEN 1575
    WHEN 'Codeology' THEN 1570
    WHEN 'PlexTech' THEN 1565
    WHEN 'Web Development at Berkeley' THEN 1560
    WHEN 'Mobile Developers of Berkeley' THEN 1555
    WHEN 'Big Data at Berkeley' THEN 1550
    WHEN 'Product Space' THEN 1545
    WHEN 'Berkeley Innovation' THEN 1540
    WHEN 'Traders at Berkeley' THEN 1535
    WHEN 'Berkeley Investment Group' THEN 1530
    WHEN 'Capital Investments at Berkeley' THEN 1525
    WHEN 'Venture Capital at Berkeley' THEN 1520
    WHEN 'Berkeley Finance Club' THEN 1515
    WHEN 'Women on Wall Street' THEN 1510
    WHEN 'The Berkeley Forum' THEN 1505
    WHEN 'Net Impact Berkeley' THEN 1500
    WHEN '180 Degrees Consulting' THEN 1495
    WHEN 'Berkeley Business Society' THEN 1490
    WHEN 'Microfinance at Berkeley' THEN 1485
    WHEN 'Scholars of Finance' THEN 1480
    WHEN 'Theta Tau' THEN 1475
    WHEN 'Alpha Epsilon Zeta' THEN 1470
    WHEN 'Camp Kesem Berkeley' THEN 1465
    WHEN 'Paws for Mental Health' THEN 1460
    WHEN 'Furries at Berkeley' THEN 1455
    WHEN 'HBSA' THEN 1450
    WHEN 'Latinx Business Student Association' THEN 1445
    WHEN 'Asian American Association' THEN 1440
    WHEN 'Ascend Berkeley' THEN 1435
    WHEN 'SAAS' THEN 1430
    WHEN 'DiversaTech' THEN 1425
    WHEN 'ANova' THEN 1420
    WHEN 'BEACN' THEN 1415
    ELSE 1450 + (random() * 100 - 50)::INTEGER  -- Random for others ~1400-1500
  END,
  -- Set wins and total_votes to match ELO
  -- Higher ELO = higher win rate
  total_votes = 560,
  wins = CASE
    WHEN elo_rating >= 1700 THEN 336  -- 60%
    WHEN elo_rating >= 1650 THEN 319  -- 57%
    WHEN elo_rating >= 1600 THEN 308  -- 55%
    WHEN elo_rating >= 1550 THEN 297  -- 53%
    WHEN elo_rating >= 1500 THEN 286  -- 51%
    WHEN elo_rating >= 1450 THEN 275  -- 49%
    ELSE 263  -- 47%
  END;

-- Now recalculate wins based on the NEW elo_rating we just set
UPDATE clubs SET
  wins = CASE
    WHEN elo_rating >= 1700 THEN 336  -- 60%
    WHEN elo_rating >= 1650 THEN 319  -- 57%
    WHEN elo_rating >= 1600 THEN 308  -- 55%
    WHEN elo_rating >= 1550 THEN 297  -- 53%
    WHEN elo_rating >= 1500 THEN 286  -- 51%
    WHEN elo_rating >= 1450 THEN 275  -- 49%
    ELSE 263  -- 47%
  END;
