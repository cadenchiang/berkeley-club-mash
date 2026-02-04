-- =======================================================================
-- Purge bot votes and recalculate ELO ratings for all clubs
-- Detected 45,964 bot votes out of 141,187 total (32.6%)
--
-- Bot detection signals used:
-- 1. Known bot patterns in session_id/fingerprint (test*, hack*, spoof*, bot*)
-- 2. Rapid-fire sessions (avg < 5s between votes, 10+ votes)
-- 3. High-volume sessions (150+ votes) combined with cloud IPs or rapid-fire
-- 4. Cloud/datacenter IPs (AWS, GCP, Azure) with rapid-fire behavior
-- =======================================================================

BEGIN;

-- Step 1: Identify rapid-fire bot sessions (avg interval < 5 seconds, 10+ votes)
CREATE TEMP TABLE rapid_fire_sessions AS
WITH session_intervals AS (
  SELECT
    session_id,
    COUNT(*) as vote_count,
    (EXTRACT(EPOCH FROM MAX(created_at)) - EXTRACT(EPOCH FROM MIN(created_at))) / NULLIF(COUNT(*) - 1, 0) as avg_interval_sec
  FROM matchups
  GROUP BY session_id
  HAVING COUNT(*) >= 10
)
SELECT session_id, vote_count, avg_interval_sec
FROM session_intervals
WHERE avg_interval_sec IS NOT NULL AND avg_interval_sec < 5.0;

-- Step 2: Identify sessions with cloud/datacenter IPs
CREATE TEMP TABLE cloud_ip_sessions AS
SELECT DISTINCT session_id
FROM matchups
WHERE ip_address IS NOT NULL AND (
  ip_address LIKE '3.%' OR ip_address LIKE '13.%' OR ip_address LIKE '15.%' OR
  ip_address LIKE '18.%' OR ip_address LIKE '34.%' OR ip_address LIKE '35.%' OR
  ip_address LIKE '43.%' OR ip_address LIKE '44.%' OR ip_address LIKE '46.%' OR
  ip_address LIKE '50.%' OR ip_address LIKE '52.%' OR ip_address LIKE '54.%' OR
  ip_address LIKE '99.%' OR ip_address LIKE '20.%' OR ip_address LIKE '40.%' OR
  ip_address LIKE '51.%' OR ip_address LIKE '65.%' OR
  ip_address LIKE '104.196.%' OR ip_address LIKE '104.199.%' OR
  ip_address LIKE '130.211.%' OR ip_address LIKE '146.148.%' OR
  ip_address LIKE '104.40.%' OR ip_address LIKE '104.41.%'
);

-- Step 3: Identify high-volume sessions (150+ votes)
CREATE TEMP TABLE high_vol_sessions AS
SELECT session_id, COUNT(*) as vote_count
FROM matchups
GROUP BY session_id
HAVING COUNT(*) > 150;

-- Step 4: Build the combined bot matchup set
CREATE TEMP TABLE bot_matchups AS
-- Signal 1: Known bot patterns
SELECT DISTINCT id FROM matchups
WHERE session_id ~* '^(test|hack|spoof|bot|fake|attack|a1b2c3)'
   OR fingerprint ~* '^(test|hack|spoof|bot|fake|attack|a1b2c3)'
   OR session_id ~* 'invalid'
   OR fingerprint ~* 'invalid'

UNION

-- Signal 2: All votes from rapid-fire sessions
SELECT m.id FROM matchups m
JOIN rapid_fire_sessions r ON m.session_id = r.session_id

UNION

-- Signal 3: High-volume sessions that also have cloud IP or rapid-fire
SELECT m.id FROM matchups m
JOIN high_vol_sessions hv ON m.session_id = hv.session_id
WHERE m.session_id IN (SELECT session_id FROM cloud_ip_sessions)
   OR m.session_id IN (SELECT session_id FROM rapid_fire_sessions)
   OR hv.vote_count > 500

UNION

-- Signal 4: Cloud IPs with rapid-fire behavior at IP level
SELECT m.id FROM matchups m
WHERE m.ip_address IN (
  SELECT ip_address FROM (
    SELECT
      ip_address,
      COUNT(*) as cnt,
      (EXTRACT(EPOCH FROM MAX(created_at)) - EXTRACT(EPOCH FROM MIN(created_at))) / NULLIF(COUNT(*) - 1, 0) as avg_int
    FROM matchups
    WHERE ip_address IS NOT NULL AND (
      ip_address LIKE '3.%' OR ip_address LIKE '13.%' OR ip_address LIKE '18.%' OR
      ip_address LIKE '34.%' OR ip_address LIKE '35.%' OR ip_address LIKE '44.%' OR
      ip_address LIKE '52.%' OR ip_address LIKE '54.%' OR ip_address LIKE '20.%' OR
      ip_address LIKE '40.%' OR ip_address LIKE '46.%' OR ip_address LIKE '50.%' OR
      ip_address LIKE '51.%' OR ip_address LIKE '65.%' OR ip_address LIKE '99.%'
    )
    GROUP BY ip_address
    HAVING COUNT(*) >= 10
  ) cloud_ips
  WHERE avg_int IS NOT NULL AND avg_int < 10.0
);

-- Log how many bot matchups found
DO $$
DECLARE
  bot_count INTEGER;
  total_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO bot_count FROM bot_matchups;
  SELECT COUNT(*) INTO total_count FROM matchups;
  RAISE NOTICE 'Bot matchups identified: % out of % total (%.1f%%)', bot_count, total_count, (bot_count::FLOAT / total_count * 100);
END $$;

-- Step 5: Delete bot matchups
DELETE FROM matchups WHERE id IN (SELECT id FROM bot_matchups);

-- Step 6: Reset ALL clubs to recalculated ELO values
-- These were computed by replaying all 95,223 clean matchups chronologically
-- with K-factor = 24 (matching the current record_vote function)
-- Starting from 1500 for all clubs

UPDATE clubs SET elo_rating = 1982, wins = 219, total_votes = 282 WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'; -- Blockchain
UPDATE clubs SET elo_rating = 1681, wins = 1460, total_votes = 2595 WHERE id = '03df4d5a-dd57-4a0a-a3e3-5373e27858a1'; -- Valley Consulting Group
UPDATE clubs SET elo_rating = 1669, wins = 1422, total_votes = 2556 WHERE id = '2540c96e-82bb-4fd5-87ae-5b9c3c733fc7'; -- Data Science Society
UPDATE clubs SET elo_rating = 1624, wins = 1555, total_votes = 2675 WHERE id = 'f8fbf611-6450-437b-beda-28e794eea860'; -- BerkeleyTime
UPDATE clubs SET elo_rating = 1611, wins = 1378, total_votes = 2546 WHERE id = '5d9991d3-e31b-4b75-81b2-85e1ff9d4c6e'; -- DiversaTech
UPDATE clubs SET elo_rating = 1595, wins = 2850, total_votes = 4682 WHERE id = '174d7ac8-471d-408f-9f0b-0d5a724f7c75'; -- Free Ventures
UPDATE clubs SET elo_rating = 1593, wins = 2968, total_votes = 4892 WHERE id = 'c3221797-d476-459b-8885-ce10be328f05'; -- AI Entrepreneurs at Berkeley
UPDATE clubs SET elo_rating = 1590, wins = 1401, total_votes = 2560 WHERE id = '423b2348-5499-49f2-a957-6dc8a608e096'; -- The Berkeley Group
UPDATE clubs SET elo_rating = 1584, wins = 1371, total_votes = 2561 WHERE id = '5b10fbe7-da5e-42d7-a3f8-c1dd85e8f86e'; -- Blueprint
UPDATE clubs SET elo_rating = 1573, wins = 1381, total_votes = 2549 WHERE id = 'd3128e69-ed2e-4aa5-98b4-36880d43211e'; -- Codeology
UPDATE clubs SET elo_rating = 1570, wins = 1391, total_votes = 2577 WHERE id = '5500e44d-f7b1-4f57-ab2d-321bf0cb8d84'; -- Berkeley Consulting
UPDATE clubs SET elo_rating = 1564, wins = 1348, total_votes = 2522 WHERE id = '0e455f5c-44b0-43c1-8239-ff433dd9b749'; -- Calisthenics Club
UPDATE clubs SET elo_rating = 1564, wins = 1395, total_votes = 2552 WHERE id = '5feb81f4-fa43-4850-b676-2ca60a58f135'; -- Camp Kesem Berkeley
UPDATE clubs SET elo_rating = 1556, wins = 1538, total_votes = 2814 WHERE id = 'b7ff8c51-b104-45b1-8698-f59adc2defd5'; -- Venture Strategy Solutions
UPDATE clubs SET elo_rating = 1556, wins = 1404, total_votes = 2573 WHERE id = 'd38dce85-cff1-4d04-85d8-3cbf7c5b852f'; -- Asian American Association
UPDATE clubs SET elo_rating = 1555, wins = 1394, total_votes = 2568 WHERE id = 'dcd972f1-c04c-4be3-ab17-a774d4de1ffa'; -- UpSync
UPDATE clubs SET elo_rating = 1554, wins = 1391, total_votes = 2558 WHERE id = 'e3da9975-ef0b-4555-adf3-4a9ee9735270'; -- Ascend Berkeley
UPDATE clubs SET elo_rating = 1552, wins = 1539, total_votes = 2788 WHERE id = 'd1f0ea40-1669-4239-9b5b-4b0b7d36f649'; -- Net Impact Berkeley
UPDATE clubs SET elo_rating = 1550, wins = 1399, total_votes = 2595 WHERE id = '0a7c464a-0ef5-4c78-8326-fcd9c0c86851'; -- Innovative Design
UPDATE clubs SET elo_rating = 1548, wins = 1398, total_votes = 2573 WHERE id = 'aaa8b94f-6df9-4a03-aa03-ea1b553345f4'; -- The Berkeley Forum
UPDATE clubs SET elo_rating = 1546, wins = 1515, total_votes = 2741 WHERE id = '7cb9ca4e-85a9-4ecb-85a7-d66cf222453f'; -- Codebase
UPDATE clubs SET elo_rating = 1543, wins = 1361, total_votes = 2540 WHERE id = 'afd51520-1820-48f8-8fb8-916ecc1430f7'; -- 180 Degrees Consulting
UPDATE clubs SET elo_rating = 1530, wins = 1530, total_votes = 2833 WHERE id = 'aedd1a2e-a0ca-4012-a616-07d8ed67c396'; -- Machine Learning at Berkeley
UPDATE clubs SET elo_rating = 1529, wins = 1388, total_votes = 2566 WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c'; -- Furries at Berkeley
UPDATE clubs SET elo_rating = 1524, wins = 1382, total_votes = 2565 WHERE id = '1c747a03-0e8f-48fa-a0b2-14ed169818b1'; -- BCEC
UPDATE clubs SET elo_rating = 1517, wins = 1375, total_votes = 2557 WHERE id = 'ea1331a3-64da-4fcc-b523-71bbc41467df'; -- Product Space
UPDATE clubs SET elo_rating = 1516, wins = 1506, total_votes = 2799 WHERE id = 'bdb3bc72-f439-4ed9-916b-4a98ae66f02c'; -- Berkeley Investment Group
UPDATE clubs SET elo_rating = 1512, wins = 1377, total_votes = 2563 WHERE id = '5e974d3a-170e-4816-8c85-d2cc2ae59f1c'; -- Venture Capital at Berkeley
UPDATE clubs SET elo_rating = 1507, wins = 1393, total_votes = 2593 WHERE id = '67d7ab80-2204-427f-804a-1d98553bfdce'; -- Web Development at Berkeley
UPDATE clubs SET elo_rating = 1504, wins = 1365, total_votes = 2559 WHERE id = '07168e84-f448-448e-b5f5-c11dce940fd9'; -- Traders at Berkeley
UPDATE clubs SET elo_rating = 1501, wins = 1375, total_votes = 2561 WHERE id = '45cadb5b-26f0-479c-a991-954bc56df93c'; -- Mobile Developers of Berkeley
UPDATE clubs SET elo_rating = 1500, wins = 1367, total_votes = 2558 WHERE id = '2cb3dfd1-491c-4724-9f6c-641c17971b97'; -- BJJ at Berkeley
UPDATE clubs SET elo_rating = 1498, wins = 1498, total_votes = 2799 WHERE id = 'fbdcde41-48ef-4568-b2fe-b4375b5d69d2'; -- Voyager Consulting
UPDATE clubs SET elo_rating = 1498, wins = 1399, total_votes = 2608 WHERE id = 'd9e7b16f-45f2-40ea-91f2-f9cc4a70d2ad'; -- CMG Strategy Consulting
UPDATE clubs SET elo_rating = 1494, wins = 1388, total_votes = 2572 WHERE id = 'ae64b5e7-0fea-497a-bf64-4e79d15772f0'; -- Big Data at Berkeley
UPDATE clubs SET elo_rating = 1492, wins = 1348, total_votes = 2538 WHERE id = 'fb16d210-c0fe-4c3d-a6e2-57dd78b0baac'; -- BEACN
UPDATE clubs SET elo_rating = 1486, wins = 1384, total_votes = 2573 WHERE id = '75462235-53ae-4318-9df1-7c5b09a83456'; -- Berkeley PBL
UPDATE clubs SET elo_rating = 1485, wins = 1358, total_votes = 2553 WHERE id = '7b99f196-fd84-4144-a429-2ee5d1d3774a'; -- ANova
UPDATE clubs SET elo_rating = 1485, wins = 1480, total_votes = 2785 WHERE id = 'bb35c455-b53f-4b78-bc01-c0e844158fb3'; -- Launchpad
UPDATE clubs SET elo_rating = 1484, wins = 1369, total_votes = 2552 WHERE id = '0fea1fbe-34e0-47df-99d1-a9453d25225e'; -- Berkeley Innovation
UPDATE clubs SET elo_rating = 1473, wins = 1369, total_votes = 2562 WHERE id = '9a24dd5f-6f23-45c6-b275-60ff9488df3b'; -- Theta Tau
UPDATE clubs SET elo_rating = 1471, wins = 1378, total_votes = 2579 WHERE id = 'e8f8d8b3-d62e-42aa-9e1e-1590c8749d48'; -- Paws for Mental Health
UPDATE clubs SET elo_rating = 1471, wins = 1512, total_votes = 2820 WHERE id = '60dc17e3-5fbc-468d-ad1a-efba8b3d2cce'; -- Berkeley Business Society
UPDATE clubs SET elo_rating = 1471, wins = 1392, total_votes = 2593 WHERE id = '6734856d-12c3-4d49-9d80-e9cd9de9fe7f'; -- HBSA
UPDATE clubs SET elo_rating = 1468, wins = 1353, total_votes = 2537 WHERE id = '7164db38-440f-4abb-bb27-5396db0d0f6b'; -- Undergraduate Finance Association
UPDATE clubs SET elo_rating = 1467, wins = 1366, total_votes = 2557 WHERE id = '4c7cf139-33b6-4b7d-ba36-821a5282fbf6'; -- Undergraduate Real Estate Club
UPDATE clubs SET elo_rating = 1466, wins = 1371, total_votes = 2568 WHERE id = '99008bf3-96d6-4593-855d-e8e95c4319d6'; -- Global Research and Consulting
UPDATE clubs SET elo_rating = 1466, wins = 151, total_votes = 225 WHERE id = '82ce10eb-0da9-4c70-a8af-d3232e9af8ba'; -- Salsa at Cal
UPDATE clubs SET elo_rating = 1458, wins = 1372, total_votes = 2564 WHERE id = 'a418ea5d-e071-4266-99ef-a17fd69f8322'; -- Berkeley Finance Club
UPDATE clubs SET elo_rating = 1453, wins = 1351, total_votes = 2541 WHERE id = 'c0fd9308-4684-4dce-a3a0-0e3c68e4f407'; -- Women on Wall Street
UPDATE clubs SET elo_rating = 1453, wins = 1453, total_votes = 2722 WHERE id = 'da09bbb7-5d30-4e8a-95f7-336638266d8f'; -- Next Generation Consulting
UPDATE clubs SET elo_rating = 1449, wins = 1448, total_votes = 2721 WHERE id = 'd161bfc7-211f-4487-a418-a3544c142de7'; -- Capital Investments at Berkeley
UPDATE clubs SET elo_rating = 1444, wins = 1369, total_votes = 2558 WHERE id = '0ebc164b-61e9-4fb4-93c4-5674bacfd00b'; -- Nova Consulting
UPDATE clubs SET elo_rating = 1442, wins = 1371, total_votes = 2572 WHERE id = '62134dd5-d74a-4728-8629-c1054a35fae7'; -- Blackskies Investments
UPDATE clubs SET elo_rating = 1440, wins = 1389, total_votes = 2595 WHERE id = '3a462083-e72a-4bc3-990f-628e542e8248'; -- PlexTech
UPDATE clubs SET elo_rating = 1438, wins = 1369, total_votes = 2566 WHERE id = 'b1ffef9c-6df6-4ff4-a53a-0428d9042bf2'; -- Berkeley ABA
UPDATE clubs SET elo_rating = 1437, wins = 1342, total_votes = 2523 WHERE id = '7f5c9ae4-85ea-4dca-86c8-3d25cb2de86a'; -- Phoenix Consulting Group
UPDATE clubs SET elo_rating = 1434, wins = 3549, total_votes = 6253 WHERE id = '18db0409-32b9-4e32-9970-1068b9134f03'; -- Entrepreneurs @ Berkeley
UPDATE clubs SET elo_rating = 1432, wins = 1381, total_votes = 2586 WHERE id = 'e7768c68-727a-4b00-9a8c-baadc9229144'; -- SAAS
UPDATE clubs SET elo_rating = 1432, wins = 1373, total_votes = 2578 WHERE id = '8a36a4a8-db9c-425e-a37f-c39b35abedc6'; -- CalTV
UPDATE clubs SET elo_rating = 1423, wins = 1348, total_votes = 2548 WHERE id = 'a6b80921-dedb-4987-9855-90de91f0ae6f'; -- Undergraduate Marketing Association
UPDATE clubs SET elo_rating = 1420, wins = 1323, total_votes = 2515 WHERE id = 'c31aae7f-b700-4d81-b6b3-de1684de1c55'; -- Pi Sigma Epsilon
UPDATE clubs SET elo_rating = 1418, wins = 1373, total_votes = 2569 WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b'; -- Beta Alpha Psi
UPDATE clubs SET elo_rating = 1414, wins = 1359, total_votes = 2557 WHERE id = '88e85321-7ceb-4c63-9f52-8e1b23125e27'; -- Delta Consulting
UPDATE clubs SET elo_rating = 1410, wins = 1352, total_votes = 2547 WHERE id = '993463c4-62c9-479b-af95-aa5277867eed'; -- SBC Strategy Consulting
UPDATE clubs SET elo_rating = 1410, wins = 1369, total_votes = 2592 WHERE id = 'f38df864-8e8d-4532-bf56-96c381f5131f'; -- Consult Your Community
UPDATE clubs SET elo_rating = 1402, wins = 1368, total_votes = 2573 WHERE id = 'd21299a6-3dd8-44bb-874d-be7d272280f4'; -- Healthcare Consulting Group
UPDATE clubs SET elo_rating = 1376, wins = 1364, total_votes = 2580 WHERE id = '1b26f411-9154-4a70-b71c-7eaaf9c2a89c'; -- imagiCal
UPDATE clubs SET elo_rating = 1375, wins = 1360, total_votes = 2569 WHERE id = 'fd040ee4-efd4-47c2-a2d2-ef77fd504a76'; -- Latinx Business Student Association
UPDATE clubs SET elo_rating = 1367, wins = 1363, total_votes = 2582 WHERE id = '8f20ef85-d269-47d9-99e2-8d5d42e87999'; -- Scholars of Finance
UPDATE clubs SET elo_rating = 1364, wins = 1330, total_votes = 2534 WHERE id = 'ef2b8429-dc06-47ad-be45-88ffee59c58b'; -- Microfinance at Berkeley
UPDATE clubs SET elo_rating = 1334, wins = 1378, total_votes = 2627 WHERE id = '82923e22-d368-4dd4-bcd0-22d885635bbb'; -- Alpha Epsilon Zeta

-- Clean up temp tables
DROP TABLE IF EXISTS rapid_fire_sessions;
DROP TABLE IF EXISTS cloud_ip_sessions;
DROP TABLE IF EXISTS high_vol_sessions;
DROP TABLE IF EXISTS bot_matchups;

COMMIT;
