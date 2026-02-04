-- =======================================================================
-- Phase 2: Purge targeted bot sessions and recalculate ELOs
--
-- These are bot sessions where a single club appears in 70%+ of matchups
-- and wins 85%+ of them - clear targeted botting for specific clubs.
--
-- Also removes all votes from known bot IP 107.21.89.25 (AWS EC2)
-- which was used across 10+ sessions with rotating fingerprints.
--
-- Clubs affected:
--   Blockchain: 14 targeted sessions, 264 bot votes
--   Entrepreneurs @ Berkeley: 1 targeted session, 200 bot votes
--   Free Ventures: 1 targeted session, 8 bot votes
-- =======================================================================

BEGIN;

-- Step 1: Delete targeted bot sessions
DELETE FROM matchups WHERE session_id IN (
  '091736c7-dc11-4505-9fe1-cdd0ae9c198d',  -- Entrepreneurs @ Berkeley bot (200 votes)
  '17e6dcad-664f-4504-970d-be80e1be45e3',  -- Blockchain bot (104 votes)
  'f3ce57ab-892d-45ce-ab45-bd5733beb565',  -- Blockchain bot (81 votes)
  '2ffe3ea2-5ac0-48a0-9e80-b7fa1c72ec01',  -- Blockchain bot (9 votes)
  'c7c2bc4b-adf0-4468-a8fe-ceb75ad68f6f',  -- Blockchain bot (9 votes)
  '6800989c-7a09-4c1d-87a7-8879463f7c4a',  -- Free Ventures bot (8 votes)
  '77fdeec4-6f62-4eee-b3db-6ce4c000e59c',  -- Blockchain bot (8 votes)
  'fb31044f-7301-4928-b513-38566261af3a',  -- Blockchain bot (7 votes)
  '6b98bb82-7a94-4f79-9cbb-dab5fdb3d4d0',  -- Blockchain bot (7 votes)
  '1b0734fe-e220-410a-8377-44cf82e08c86',  -- Blockchain bot (6 votes)
  '05402635-1418-4529-bebe-67a7f2a78492',  -- Blockchain bot (6 votes)
  '7d85358d-80eb-442f-a84c-fc0411803914',  -- Blockchain bot (6 votes)
  '9893836d-b65f-4f78-b85d-8a784510c8d3',  -- Blockchain bot (6 votes)
  '3f54e4b8-e3fa-415e-9daa-a19cce063b50',  -- Blockchain bot (6 votes)
  '0ca9b06e-d8b3-4bb1-a8e3-53d92c874676',  -- Blockchain bot (5 votes)
  '286b9128-2b87-46e8-9a2c-7a9797180adb'   -- Blockchain bot (4 votes)
);

-- Step 2: Delete remaining votes from known bot IP
DELETE FROM matchups WHERE ip_address = '107.21.89.25';

-- Step 3: Ban the bot IP
INSERT INTO banned_ips (ip_address, reason) VALUES
  ('107.21.89.25', 'AWS EC2 bot - targeted Blockchain voting across 10+ sessions')
ON CONFLICT (ip_address) DO NOTHING;

-- Step 4: Update all club ELOs (recalculated from 94,757 clean matchups, K=24)
UPDATE clubs SET elo_rating = 1673, wins = 1211, total_votes = 2592 WHERE id = '03df4d5a-dd57-4a0a-a3e3-5373e27858a1'; -- Valley Consulting Group
UPDATE clubs SET elo_rating = 1670, wins = 1330, total_votes = 2555 WHERE id = '2540c96e-82bb-4fd5-87ae-5b9c3c733fc7'; -- Data Science Society
UPDATE clubs SET elo_rating = 1627, wins = 1348, total_votes = 2672 WHERE id = 'f8fbf611-6450-437b-beda-28e794eea860'; -- BerkeleyTime
UPDATE clubs SET elo_rating = 1613, wins = 1324, total_votes = 2544 WHERE id = '5d9991d3-e31b-4b75-81b2-85e1ff9d4c6e'; -- DiversaTech
UPDATE clubs SET elo_rating = 1605, wins = 1381, total_votes = 2558 WHERE id = '5500e44d-f7b1-4f57-ab2d-321bf0cb8d84'; -- Berkeley Consulting
UPDATE clubs SET elo_rating = 1604, wins = 1230, total_votes = 2559 WHERE id = '423b2348-5499-49f2-a957-6dc8a608e096'; -- The Berkeley Group
UPDATE clubs SET elo_rating = 1598, wins = 3499, total_votes = 4694 WHERE id = 'c3221797-d476-459b-8885-ce10be328f05'; -- AI Entrepreneurs at Berkeley
UPDATE clubs SET elo_rating = 1591, wins = 3396, total_votes = 4672 WHERE id = '174d7ac8-471d-408f-9f0b-0d5a724f7c75'; -- Free Ventures
UPDATE clubs SET elo_rating = 1586, wins = 1346, total_votes = 2561 WHERE id = '5b10fbe7-da5e-42d7-a3f8-c1dd85e8f86e'; -- Blueprint
UPDATE clubs SET elo_rating = 1584, wins = 1293, total_votes = 2814 WHERE id = 'aedd1a2e-a0ca-4012-a616-07d8ed67c396'; -- Machine Learning at Berkeley
UPDATE clubs SET elo_rating = 1575, wins = 1315, total_votes = 2548 WHERE id = 'd3128e69-ed2e-4aa5-98b4-36880d43211e'; -- Codeology
UPDATE clubs SET elo_rating = 1569, wins = 1345, total_votes = 2741 WHERE id = '7cb9ca4e-85a9-4ecb-85a7-d66cf222453f'; -- Codebase
UPDATE clubs SET elo_rating = 1568, wins = 1303, total_votes = 2550 WHERE id = '5feb81f4-fa43-4850-b676-2ca60a58f135'; -- Camp Kesem Berkeley
UPDATE clubs SET elo_rating = 1566, wins = 1347, total_votes = 2521 WHERE id = '0e455f5c-44b0-43c1-8239-ff433dd9b749'; -- Calisthenics Club
UPDATE clubs SET elo_rating = 1560, wins = 1190, total_votes = 2812 WHERE id = 'b7ff8c51-b104-45b1-8698-f59adc2defd5'; -- Venture Strategy Solutions
UPDATE clubs SET elo_rating = 1556, wins = 1337, total_votes = 2573 WHERE id = 'd38dce85-cff1-4d04-85d8-3cbf7c5b852f'; -- Asian American Association
UPDATE clubs SET elo_rating = 1554, wins = 1249, total_votes = 2788 WHERE id = 'd1f0ea40-1669-4239-9b5b-4b0b7d36f649'; -- Net Impact Berkeley
UPDATE clubs SET elo_rating = 1553, wins = 1357, total_votes = 2534 WHERE id = 'afd51520-1820-48f8-8fb8-916ecc1430f7'; -- 180 Degrees Consulting
UPDATE clubs SET elo_rating = 1553, wins = 1369, total_votes = 2594 WHERE id = '0a7c464a-0ef5-4c78-8326-fcd9c0c86851'; -- Innovative Design
UPDATE clubs SET elo_rating = 1552, wins = 1240, total_votes = 2566 WHERE id = 'dcd972f1-c04c-4be3-ab17-a774d4de1ffa'; -- UpSync
UPDATE clubs SET elo_rating = 1551, wins = 1213, total_votes = 2571 WHERE id = 'aaa8b94f-6df9-4a03-aa03-ea1b553345f4'; -- The Berkeley Forum
UPDATE clubs SET elo_rating = 1548, wins = 1403, total_votes = 2557 WHERE id = 'e3da9975-ef0b-4555-adf3-4a9ee9735270'; -- Ascend Berkeley
UPDATE clubs SET elo_rating = 1545, wins = 1208, total_votes = 2538 WHERE id = '07168e84-f448-448e-b5f5-c11dce940fd9'; -- Traders at Berkeley
UPDATE clubs SET elo_rating = 1543, wins = 1311, total_votes = 2564 WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c'; -- Furries at Berkeley
UPDATE clubs SET elo_rating = 1531, wins = 11, total_votes = 17 WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'; -- Blockchain
UPDATE clubs SET elo_rating = 1529, wins = 1202, total_votes = 2576 WHERE id = '67d7ab80-2204-427f-804a-1d98553bfdce'; -- Web Development at Berkeley
UPDATE clubs SET elo_rating = 1529, wins = 1353, total_votes = 2565 WHERE id = '1c747a03-0e8f-48fa-a0b2-14ed169818b1'; -- BCEC
UPDATE clubs SET elo_rating = 1528, wins = 1335, total_votes = 2553 WHERE id = 'ae64b5e7-0fea-497a-bf64-4e79d15772f0'; -- Big Data at Berkeley
UPDATE clubs SET elo_rating = 1520, wins = 1329, total_votes = 2536 WHERE id = '0fea1fbe-34e0-47df-99d1-a9453d25225e'; -- Berkeley Innovation
UPDATE clubs SET elo_rating = 1517, wins = 1206, total_votes = 2561 WHERE id = '5e974d3a-170e-4816-8c85-d2cc2ae59f1c'; -- Venture Capital at Berkeley
UPDATE clubs SET elo_rating = 1517, wins = 1384, total_votes = 2798 WHERE id = 'bdb3bc72-f439-4ed9-916b-4a98ae66f02c'; -- Berkeley Investment Group
UPDATE clubs SET elo_rating = 1507, wins = 1319, total_votes = 2556 WHERE id = 'ea1331a3-64da-4fcc-b523-71bbc41467df'; -- Product Space
UPDATE clubs SET elo_rating = 1505, wins = 1365, total_votes = 2556 WHERE id = '2cb3dfd1-491c-4724-9f6c-641c17971b97'; -- BJJ at Berkeley
UPDATE clubs SET elo_rating = 1501, wins = 1162, total_votes = 2797 WHERE id = 'fbdcde41-48ef-4568-b2fe-b4375b5d69d2'; -- Voyager Consulting
UPDATE clubs SET elo_rating = 1500, wins = 1310, total_votes = 2603 WHERE id = 'd9e7b16f-45f2-40ea-91f2-f9cc4a70d2ad'; -- CMG Strategy Consulting
UPDATE clubs SET elo_rating = 1496, wins = 1377, total_votes = 2535 WHERE id = 'fb16d210-c0fe-4c3d-a6e2-57dd78b0baac'; -- BEACN
UPDATE clubs SET elo_rating = 1494, wins = 1286, total_votes = 2559 WHERE id = '45cadb5b-26f0-479c-a991-954bc56df93c'; -- Mobile Developers of Berkeley
UPDATE clubs SET elo_rating = 1488, wins = 1376, total_votes = 2551 WHERE id = '7b99f196-fd84-4144-a429-2ee5d1d3774a'; -- ANova
UPDATE clubs SET elo_rating = 1487, wins = 1232, total_votes = 2785 WHERE id = 'bb35c455-b53f-4b78-bc01-c0e844158fb3'; -- Launchpad
UPDATE clubs SET elo_rating = 1486, wins = 1345, total_votes = 2572 WHERE id = '75462235-53ae-4318-9df1-7c5b09a83456'; -- Berkeley PBL
UPDATE clubs SET elo_rating = 1477, wins = 1251, total_votes = 2562 WHERE id = '9a24dd5f-6f23-45c6-b275-60ff9488df3b'; -- Theta Tau
UPDATE clubs SET elo_rating = 1477, wins = 1310, total_votes = 2592 WHERE id = '6734856d-12c3-4d49-9d80-e9cd9de9fe7f'; -- HBSA
UPDATE clubs SET elo_rating = 1473, wins = 1356, total_votes = 2817 WHERE id = '60dc17e3-5fbc-468d-ad1a-efba8b3d2cce'; -- Berkeley Business Society
UPDATE clubs SET elo_rating = 1471, wins = 1188, total_votes = 2535 WHERE id = '7164db38-440f-4abb-bb27-5396db0d0f6b'; -- Undergraduate Finance Association
UPDATE clubs SET elo_rating = 1470, wins = 128, total_votes = 225 WHERE id = '82ce10eb-0da9-4c70-a8af-d3232e9af8ba'; -- Salsa at Cal
UPDATE clubs SET elo_rating = 1466, wins = 1210, total_votes = 2555 WHERE id = '4c7cf139-33b6-4b7d-ba36-821a5282fbf6'; -- Undergraduate Real Estate Club
UPDATE clubs SET elo_rating = 1465, wins = 1213, total_votes = 2574 WHERE id = '3a462083-e72a-4bc3-990f-628e542e8248'; -- PlexTech
UPDATE clubs SET elo_rating = 1464, wins = 1245, total_votes = 2566 WHERE id = '99008bf3-96d6-4593-855d-e8e95c4319d6'; -- Global Research and Consulting
UPDATE clubs SET elo_rating = 1464, wins = 1313, total_votes = 2563 WHERE id = 'a418ea5d-e071-4266-99ef-a17fd69f8322'; -- Berkeley Finance Club
UPDATE clubs SET elo_rating = 1457, wins = 1370, total_votes = 2566 WHERE id = 'b1ffef9c-6df6-4ff4-a53a-0428d9042bf2'; -- Berkeley ABA
UPDATE clubs SET elo_rating = 1457, wins = 1201, total_votes = 2541 WHERE id = 'c0fd9308-4684-4dce-a3a0-0e3c68e4f407'; -- Women on Wall Street
UPDATE clubs SET elo_rating = 1452, wins = 1309, total_votes = 2721 WHERE id = 'd161bfc7-211f-4487-a418-a3544c142de7'; -- Capital Investments at Berkeley
UPDATE clubs SET elo_rating = 1449, wins = 1274, total_votes = 2722 WHERE id = 'da09bbb7-5d30-4e8a-95f7-336638266d8f'; -- Next Generation Consulting
UPDATE clubs SET elo_rating = 1447, wins = 1244, total_votes = 2527 WHERE id = '993463c4-62c9-479b-af95-aa5277867eed'; -- SBC Strategy Consulting
UPDATE clubs SET elo_rating = 1445, wins = 1321, total_votes = 2572 WHERE id = '62134dd5-d74a-4728-8629-c1054a35fae7'; -- Blackskies Investments
UPDATE clubs SET elo_rating = 1445, wins = 1248, total_votes = 2523 WHERE id = '7f5c9ae4-85ea-4dca-86c8-3d25cb2de86a'; -- Phoenix Consulting Group
UPDATE clubs SET elo_rating = 1444, wins = 1267, total_votes = 2557 WHERE id = '0ebc164b-61e9-4fb4-93c4-5674bacfd00b'; -- Nova Consulting
UPDATE clubs SET elo_rating = 1439, wins = 1276, total_votes = 2577 WHERE id = 'e8f8d8b3-d62e-42aa-9e1e-1590c8749d48'; -- Paws for Mental Health
UPDATE clubs SET elo_rating = 1436, wins = 1234, total_votes = 2586 WHERE id = 'e7768c68-727a-4b00-9a8c-baadc9229144'; -- SAAS
UPDATE clubs SET elo_rating = 1436, wins = 1282, total_votes = 2573 WHERE id = 'f38df864-8e8d-4532-bf56-96c381f5131f'; -- Consult Your Community
UPDATE clubs SET elo_rating = 1436, wins = 1334, total_votes = 2577 WHERE id = '8a36a4a8-db9c-425e-a37f-c39b35abedc6'; -- CalTV
UPDATE clubs SET elo_rating = 1426, wins = 1253, total_votes = 6058 WHERE id = '18db0409-32b9-4e32-9970-1068b9134f03'; -- Entrepreneurs @ Berkeley
UPDATE clubs SET elo_rating = 1425, wins = 1203, total_votes = 2548 WHERE id = 'a6b80921-dedb-4987-9855-90de91f0ae6f'; -- Undergraduate Marketing Association
UPDATE clubs SET elo_rating = 1422, wins = 1195, total_votes = 2515 WHERE id = 'c31aae7f-b700-4d81-b6b3-de1684de1c55'; -- Pi Sigma Epsilon
UPDATE clubs SET elo_rating = 1419, wins = 1258, total_votes = 2554 WHERE id = '88e85321-7ceb-4c63-9f52-8e1b23125e27'; -- Delta Consulting
UPDATE clubs SET elo_rating = 1413, wins = 1363, total_votes = 2569 WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b'; -- Beta Alpha Psi
UPDATE clubs SET elo_rating = 1399, wins = 1319, total_votes = 2571 WHERE id = 'd21299a6-3dd8-44bb-874d-be7d272280f4'; -- Healthcare Consulting Group
UPDATE clubs SET elo_rating = 1395, wins = 1250, total_votes = 2560 WHERE id = '1b26f411-9154-4a70-b71c-7eaaf9c2a89c'; -- imagiCal
UPDATE clubs SET elo_rating = 1379, wins = 1309, total_votes = 2568 WHERE id = 'fd040ee4-efd4-47c2-a2d2-ef77fd504a76'; -- Latinx Business Student Association
UPDATE clubs SET elo_rating = 1365, wins = 1194, total_votes = 2581 WHERE id = '8f20ef85-d269-47d9-99e2-8d5d42e87999'; -- Scholars of Finance
UPDATE clubs SET elo_rating = 1365, wins = 1262, total_votes = 2534 WHERE id = 'ef2b8429-dc06-47ad-be45-88ffee59c58b'; -- Microfinance at Berkeley
UPDATE clubs SET elo_rating = 1343, wins = 1440, total_votes = 2627 WHERE id = '82923e22-d368-4dd4-bcd0-22d885635bbb'; -- Alpha Epsilon Zeta

COMMIT;
