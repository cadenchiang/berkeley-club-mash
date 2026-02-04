-- =======================================================================
-- Phase 4: Purge noise-bot sessions
--
-- These are sessions that don't target any specific club but generate
-- large volumes of random votes at inhuman speeds, diluting real
-- preferences toward 50/50 and compressing the ELO spread.
--
-- Detection criteria:
--   - Rapid-fire: avg <4s between votes, 10+ votes
--   - Large random: 50+ votes with avg <15s interval
--   - Suspicious fingerprints: 200+ total votes across 5+ sessions
--
-- 37 bot sessions removed, 2,715 noise votes
-- Remaining: 86,117 clean matchups
-- =======================================================================

BEGIN;

-- Step 1: Delete noise-bot sessions
DELETE FROM matchups WHERE session_id IN (
  '033f25fa-d55b-4990-8ad0-d336ec2a8c50',  -- 412 votes, 5.5s avg
  '041eef1f-3a6f-4317-aabc-110f7dcf9fdf',  -- 272 votes, 6.4s avg
  '04a45179-0aed-4e9f-ae84-1b657a7f8bcc',  -- 73 votes
  '1a186168-32bf-460f-a689-aa2c2d2a6da9',  -- 138 votes, 6.2s avg
  '1eeb84de-051c-4bb4-9fed-f2907487c204',  -- 90 votes
  '2b2ba603-0849-4556-8be1-5342fbae9e4c',  -- 13 votes
  '37c34c4f-c94f-4b28-b5a4-45cd47f4852f',  -- 65 votes
  '3f22a6fe-3cc9-458d-bf87-6efafee53b36',  -- 181 votes, 5.4s avg
  '44f70bc9-00de-4888-863d-004797bd31b8',  -- 5 votes
  '48373d1e-425d-4756-b25b-3326e908ce85',  -- 93 votes
  '55847cb2-23b4-4fbc-aaf5-b0e362697246',  -- 6 votes
  '567636bb-2d1a-4334-b8db-624a858bad6c',  -- 79 votes, 5.1s avg
  '5ae87682-584f-4bc3-b5c6-234eddeaf763',  -- 9 votes
  '5f1603a7-f2e0-4a92-a776-48057b2cca6e',  -- 70 votes
  '6126f8fa-f70d-4712-8cf4-8ce63d4baf07',  -- 94 votes
  '6fb10dd4-604d-4a63-a6c4-e95768740eda',  -- 20 votes
  '7ca2311b-fd16-4004-b573-5b2a110d20aa',  -- 7 votes
  '7cf9afaa-a2a2-419b-9afc-8a93bdd6a38f',  -- 62 votes
  '7f99b0a7-f12e-4983-a502-1615a75f6f1c',  -- 10 votes
  '82213936-3a29-4259-a364-fb386232c571',  -- 73 votes
  '83bfe561-c798-4dc8-9254-7676b33d1c86',  -- 16 votes
  '8e04f8a4-f6c7-430b-af48-72d606c9f9b6',  -- 92 votes
  '9a1ca06a-a07d-4082-a3e6-a0ed934dc08d',  -- 11 votes
  'a2e37e8e-3b07-429a-bd04-960219050f10',  -- 61 votes
  'ab94716e-7dfe-4e42-be0b-b808b30d0606',  -- 106 votes
  'b51d9fdf-c167-4647-8c24-dce4a4d1cc94',  -- 139 votes, 8.7s avg
  'bebc6bb0-6515-4996-8c3d-32e9e4281d12',  -- 50 votes
  'bf330e73-e18d-43b9-9528-77b6194f2759',  -- 11 votes
  'bf3e07eb-6309-4a00-a9a7-f33fbf1da3da',  -- 145 votes, 5.3s avg
  'c2b96a93-5713-4299-aaf4-87ec4c8b200c',  -- 64 votes
  'c9b38068-23f2-4107-b842-29d0825a3da8',  -- 31 votes
  'd298fae3-827c-4d18-9b52-6dc5c2c2d568',  -- 97 votes
  'd3575dd9-191a-46b6-9093-6b0df2cd804b',  -- 78 votes
  'd67d6b4a-4b91-4daf-b31c-fe25069d37f0',  -- 13 votes
  'd7bd37e9-e880-44df-b13e-0112c0226179',  -- 16 votes
  'eb150e88-fb7d-4410-afd4-310654e9bc64',  -- 8 votes
  'efee8f39-b059-4b9d-9abb-b6a4226a4387'   -- 5 votes
);

-- Step 2: Update all club ELOs (recalculated from 86,117 clean matchups, K=24)
UPDATE clubs SET elo_rating = 1684, wins = 1259, total_votes = 2449 WHERE id = '2540c96e-82bb-4fd5-87ae-5b9c3c733fc7'; -- Data Science Society
UPDATE clubs SET elo_rating = 1663, wins = 1303, total_votes = 2462 WHERE id = 'f8fbf611-6450-437b-beda-28e794eea860'; -- BerkeleyTime
UPDATE clubs SET elo_rating = 1640, wins = 1137, total_votes = 2456 WHERE id = '03df4d5a-dd57-4a0a-a3e3-5373e27858a1'; -- Valley Consulting Group
UPDATE clubs SET elo_rating = 1633, wins = 1173, total_votes = 2463 WHERE id = '423b2348-5499-49f2-a957-6dc8a608e096'; -- The Berkeley Group
UPDATE clubs SET elo_rating = 1628, wins = 1268, total_votes = 2462 WHERE id = '7cb9ca4e-85a9-4ecb-85a7-d66cf222453f'; -- Codebase
UPDATE clubs SET elo_rating = 1610, wins = 1212, total_votes = 2463 WHERE id = 'aedd1a2e-a0ca-4012-a616-07d8ed67c396'; -- Machine Learning at Berkeley
UPDATE clubs SET elo_rating = 1594, wins = 1298, total_votes = 2443 WHERE id = '5500e44d-f7b1-4f57-ab2d-321bf0cb8d84'; -- Berkeley Consulting
UPDATE clubs SET elo_rating = 1592, wins = 1317, total_votes = 2450 WHERE id = 'afd51520-1820-48f8-8fb8-916ecc1430f7'; -- 180 Degrees Consulting
UPDATE clubs SET elo_rating = 1583, wins = 1277, total_votes = 2458 WHERE id = '5d9991d3-e31b-4b75-81b2-85e1ff9d4c6e'; -- DiversaTech
UPDATE clubs SET elo_rating = 1571, wins = 1245, total_votes = 2443 WHERE id = 'd3128e69-ed2e-4aa5-98b4-36880d43211e'; -- Codeology
UPDATE clubs SET elo_rating = 1570, wins = 1241, total_votes = 2453 WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c'; -- Furries at Berkeley
UPDATE clubs SET elo_rating = 1562, wins = 1134, total_votes = 2453 WHERE id = 'aaa8b94f-6df9-4a03-aa03-ea1b553345f4'; -- The Berkeley Forum
UPDATE clubs SET elo_rating = 1562, wins = 1171, total_votes = 2444 WHERE id = 'd1f0ea40-1669-4239-9b5b-4b0b7d36f649'; -- Net Impact Berkeley
UPDATE clubs SET elo_rating = 1556, wins = 1256, total_votes = 2439 WHERE id = '5b10fbe7-da5e-42d7-a3f8-c1dd85e8f86e'; -- Blueprint
UPDATE clubs SET elo_rating = 1546, wins = 1245, total_votes = 2443 WHERE id = 'd161bfc7-211f-4487-a418-a3544c142de7'; -- Capital Investments at Berkeley
UPDATE clubs SET elo_rating = 1544, wins = 1166, total_votes = 2455 WHERE id = '07168e84-f448-448e-b5f5-c11dce940fd9'; -- Traders at Berkeley
UPDATE clubs SET elo_rating = 1544, wins = 1282, total_votes = 2444 WHERE id = '60dc17e3-5fbc-468d-ad1a-efba8b3d2cce'; -- Berkeley Business Society
UPDATE clubs SET elo_rating = 1534, wins = 1275, total_votes = 2457 WHERE id = 'd38dce85-cff1-4d04-85d8-3cbf7c5b852f'; -- Asian American Association
UPDATE clubs SET elo_rating = 1533, wins = 1286, total_votes = 2438 WHERE id = '0e455f5c-44b0-43c1-8239-ff433dd9b749'; -- Calisthenics Club
UPDATE clubs SET elo_rating = 1531, wins = 1238, total_votes = 2445 WHERE id = '5feb81f4-fa43-4850-b676-2ca60a58f135'; -- Camp Kesem Berkeley
UPDATE clubs SET elo_rating = 1529, wins = 1293, total_votes = 2460 WHERE id = '1c747a03-0e8f-48fa-a0b2-14ed169818b1'; -- BCEC
UPDATE clubs SET elo_rating = 1525, wins = 1302, total_votes = 2458 WHERE id = 'c3221797-d476-459b-8885-ce10be328f05'; -- AI Entrepreneurs at Berkeley
UPDATE clubs SET elo_rating = 1525, wins = 1277, total_votes = 2464 WHERE id = 'ae64b5e7-0fea-497a-bf64-4e79d15772f0'; -- Big Data at Berkeley
UPDATE clubs SET elo_rating = 1524, wins = 1247, total_votes = 2462 WHERE id = 'd9e7b16f-45f2-40ea-91f2-f9cc4a70d2ad'; -- CMG Strategy Consulting
UPDATE clubs SET elo_rating = 1521, wins = 1296, total_votes = 2439 WHERE id = 'bdb3bc72-f439-4ed9-916b-4a98ae66f02c'; -- Berkeley Investment Group
UPDATE clubs SET elo_rating = 1521, wins = 1296, total_votes = 2475 WHERE id = '75462235-53ae-4318-9df1-7c5b09a83456'; -- Berkeley PBL
UPDATE clubs SET elo_rating = 1516, wins = 1272, total_votes = 2476 WHERE id = '0a7c464a-0ef5-4c78-8326-fcd9c0c86851'; -- Innovative Design
UPDATE clubs SET elo_rating = 1515, wins = 1347, total_votes = 2456 WHERE id = 'e3da9975-ef0b-4555-adf3-4a9ee9735270'; -- Ascend Berkeley
UPDATE clubs SET elo_rating = 1514, wins = 1243, total_votes = 2452 WHERE id = 'ea1331a3-64da-4fcc-b523-71bbc41467df'; -- Product Space
UPDATE clubs SET elo_rating = 1512, wins = 1307, total_votes = 2462 WHERE id = '2cb3dfd1-491c-4724-9f6c-641c17971b97'; -- BJJ at Berkeley
UPDATE clubs SET elo_rating = 1507, wins = 1158, total_votes = 2447 WHERE id = 'dcd972f1-c04c-4be3-ab17-a774d4de1ffa'; -- UpSync
UPDATE clubs SET elo_rating = 1503, wins = 1116, total_votes = 2478 WHERE id = 'fbdcde41-48ef-4568-b2fe-b4375b5d69d2'; -- Voyager Consulting
UPDATE clubs SET elo_rating = 1502, wins = 1112, total_votes = 2445 WHERE id = 'b7ff8c51-b104-45b1-8698-f59adc2defd5'; -- Venture Strategy Solutions
UPDATE clubs SET elo_rating = 1501, wins = 1346, total_votes = 2463 WHERE id = 'fb16d210-c0fe-4c3d-a6e2-57dd78b0baac'; -- BEACN
UPDATE clubs SET elo_rating = 1500, wins = 1157, total_votes = 2478 WHERE id = '3a462083-e72a-4bc3-990f-628e542e8248'; -- PlexTech
UPDATE clubs SET elo_rating = 1500, wins = 1243, total_votes = 2473 WHERE id = '45cadb5b-26f0-479c-a991-954bc56df93c'; -- Mobile Developers of Berkeley
UPDATE clubs SET elo_rating = 1499, wins = 1132, total_votes = 2469 WHERE id = '67d7ab80-2204-427f-804a-1d98553bfdce'; -- Web Development at Berkeley
UPDATE clubs SET elo_rating = 1496, wins = 1183, total_votes = 2450 WHERE id = '9a24dd5f-6f23-45c6-b275-60ff9488df3b'; -- Theta Tau
UPDATE clubs SET elo_rating = 1491, wins = 9, total_votes = 17 WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'; -- Blockchain
UPDATE clubs SET elo_rating = 1491, wins = 1289, total_votes = 2453 WHERE id = '0fea1fbe-34e0-47df-99d1-a9453d25225e'; -- Berkeley Innovation
UPDATE clubs SET elo_rating = 1491, wins = 1193, total_votes = 2449 WHERE id = '993463c4-62c9-479b-af95-aa5277867eed'; -- SBC Strategy Consulting
UPDATE clubs SET elo_rating = 1489, wins = 1160, total_votes = 2476 WHERE id = '5e974d3a-170e-4816-8c85-d2cc2ae59f1c'; -- Venture Capital at Berkeley
UPDATE clubs SET elo_rating = 1488, wins = 1188, total_votes = 2461 WHERE id = '99008bf3-96d6-4593-855d-e8e95c4319d6'; -- Global Research and Consulting
UPDATE clubs SET elo_rating = 1485, wins = 1304, total_votes = 2451 WHERE id = 'b1ffef9c-6df6-4ff4-a53a-0428d9042bf2'; -- Berkeley ABA
UPDATE clubs SET elo_rating = 1481, wins = 1219, total_votes = 2480 WHERE id = '18db0409-32b9-4e32-9970-1068b9134f03'; -- Entrepreneurs @ Berkeley
UPDATE clubs SET elo_rating = 1475, wins = 1150, total_votes = 2458 WHERE id = '7164db38-440f-4abb-bb27-5396db0d0f6b'; -- Undergraduate Finance Association
UPDATE clubs SET elo_rating = 1471, wins = 1246, total_votes = 2452 WHERE id = 'a418ea5d-e071-4266-99ef-a17fd69f8322'; -- Berkeley Finance Club
UPDATE clubs SET elo_rating = 1470, wins = 1250, total_votes = 2474 WHERE id = '6734856d-12c3-4d49-9d80-e9cd9de9fe7f'; -- HBSA
UPDATE clubs SET elo_rating = 1469, wins = 1259, total_votes = 2460 WHERE id = '62134dd5-d74a-4728-8629-c1054a35fae7'; -- Blackskies Investments
UPDATE clubs SET elo_rating = 1467, wins = 1328, total_votes = 2465 WHERE id = '7b99f196-fd84-4144-a429-2ee5d1d3774a'; -- ANova
UPDATE clubs SET elo_rating = 1465, wins = 1137, total_votes = 2444 WHERE id = '4c7cf139-33b6-4b7d-ba36-821a5282fbf6'; -- Undergraduate Real Estate Club
UPDATE clubs SET elo_rating = 1463, wins = 1186, total_votes = 2468 WHERE id = 'bb35c455-b53f-4b78-bc01-c0e844158fb3'; -- Launchpad
UPDATE clubs SET elo_rating = 1460, wins = 1265, total_votes = 2476 WHERE id = '8a36a4a8-db9c-425e-a37f-c39b35abedc6'; -- CalTV
UPDATE clubs SET elo_rating = 1459, wins = 59, total_votes = 120 WHERE id = '82ce10eb-0da9-4c70-a8af-d3232e9af8ba'; -- Salsa at Cal
UPDATE clubs SET elo_rating = 1449, wins = 1190, total_votes = 2451 WHERE id = 'da09bbb7-5d30-4e8a-95f7-336638266d8f'; -- Next Generation Consulting
UPDATE clubs SET elo_rating = 1444, wins = 1143, total_votes = 2439 WHERE id = 'a6b80921-dedb-4987-9855-90de91f0ae6f'; -- Undergraduate Marketing Association
UPDATE clubs SET elo_rating = 1438, wins = 1194, total_votes = 2444 WHERE id = '0ebc164b-61e9-4fb4-93c4-5674bacfd00b'; -- Nova Consulting
UPDATE clubs SET elo_rating = 1438, wins = 1154, total_votes = 2475 WHERE id = 'e7768c68-727a-4b00-9a8c-baadc9229144'; -- SAAS
UPDATE clubs SET elo_rating = 1433, wins = 1287, total_votes = 2448 WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b'; -- Beta Alpha Psi
UPDATE clubs SET elo_rating = 1432, wins = 1194, total_votes = 2442 WHERE id = '7f5c9ae4-85ea-4dca-86c8-3d25cb2de86a'; -- Phoenix Consulting Group
UPDATE clubs SET elo_rating = 1431, wins = 1206, total_votes = 2439 WHERE id = '174d7ac8-471d-408f-9f0b-0d5a724f7c75'; -- Free Ventures
UPDATE clubs SET elo_rating = 1425, wins = 1208, total_votes = 2475 WHERE id = 'e8f8d8b3-d62e-42aa-9e1e-1590c8749d48'; -- Paws for Mental Health
UPDATE clubs SET elo_rating = 1422, wins = 1216, total_votes = 2470 WHERE id = 'f38df864-8e8d-4532-bf56-96c381f5131f'; -- Consult Your Community
UPDATE clubs SET elo_rating = 1415, wins = 1151, total_votes = 2461 WHERE id = 'c0fd9308-4684-4dce-a3a0-0e3c68e4f407'; -- Women on Wall Street
UPDATE clubs SET elo_rating = 1413, wins = 1203, total_votes = 2468 WHERE id = '1b26f411-9154-4a70-b71c-7eaaf9c2a89c'; -- imagiCal
UPDATE clubs SET elo_rating = 1412, wins = 1202, total_votes = 2458 WHERE id = '88e85321-7ceb-4c63-9f52-8e1b23125e27'; -- Delta Consulting
UPDATE clubs SET elo_rating = 1411, wins = 1255, total_votes = 2468 WHERE id = 'd21299a6-3dd8-44bb-874d-be7d272280f4'; -- Healthcare Consulting Group
UPDATE clubs SET elo_rating = 1406, wins = 1172, total_votes = 2462 WHERE id = 'c31aae7f-b700-4d81-b6b3-de1684de1c55'; -- Pi Sigma Epsilon
UPDATE clubs SET elo_rating = 1400, wins = 1248, total_votes = 2459 WHERE id = 'fd040ee4-efd4-47c2-a2d2-ef77fd504a76'; -- Latinx Business Student Association
UPDATE clubs SET elo_rating = 1395, wins = 1139, total_votes = 2467 WHERE id = '8f20ef85-d269-47d9-99e2-8d5d42e87999'; -- Scholars of Finance
UPDATE clubs SET elo_rating = 1377, wins = 1232, total_votes = 2463 WHERE id = 'ef2b8429-dc06-47ad-be45-88ffee59c58b'; -- Microfinance at Berkeley
UPDATE clubs SET elo_rating = 1354, wins = 1371, total_votes = 2514 WHERE id = '82923e22-d368-4dd4-bcd0-22d885635bbb'; -- Alpha Epsilon Zeta

COMMIT;
