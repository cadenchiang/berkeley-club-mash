-- =======================================================================
-- Phase 3: Purge remaining bot sessions missed by previous passes
--
-- Three bot operations identified:
--   1. Anti-Entrepreneurs @ Berkeley: 74 sessions, 3,511 votes
--      (club appears in 100% of matchups but loses every one - sabotage)
--   2. Pro-AI Entrepreneurs at Berkeley: 15 sessions, 1,358 votes
--      (club appears ~50% of matchups, wins 100% - boosting)
--   3. Pro-Free Ventures: 11 sessions, 1,089 votes
--      (same pattern, many shared sessions with AI Entrepreneurs)
--   4. Pro-Berkeley PBL: 1 session, 6 votes (minor)
--
-- Detection: sessions where any club appears in 50%+ of matchups
-- (random chance is ~2.8% per club with 72 clubs)
--
-- After cleanup: 88,793 clean matchups, all ELOs recalculated from scratch
-- =======================================================================

BEGIN;

-- Step 1: Delete all 101 bot sessions
DELETE FROM matchups WHERE session_id IN (
  -- Anti-Entrepreneurs @ Berkeley sessions (74 sessions, always 0% win rate)
  '6bc8cb6a-bc12-440d-a477-068eba77bec2',
  'f3955be0-2aa5-4542-9d34-7b42358bb5a5',
  '7052d71e-d7cd-4fa5-8b5c-03f3b4458d68',
  '44e2931b-27ec-4bc0-aab5-ac00fce62c03',
  '931e7108-d21e-4a37-9a4b-a4c791227d8d',
  '34e13382-884a-43d8-8db5-c8c82122e805',
  '409cfdfc-ac57-4872-a07f-0fefcd357f52',
  'c4484dfd-a7ae-4fbd-8e75-44c3cd018003',
  'a8fdef2f-5e7a-46ae-8acc-2ff6e687135e',
  '1ec3f1f4-191f-4c8f-8aa6-1b92c8a65f90',
  '8750b23b-30e2-4e7f-a974-056b3c49ed94',
  '9ccb9b69-288f-4989-a13c-5cfc2dc57f48',
  'e8327368-5180-435c-8755-3d80fc6a6ab1',
  '454aaaed-5b9a-467b-911b-06c369b11c36',
  'a6236567-5887-4ee5-b363-b7ca04748290',
  '37633d2d-d3c5-46e5-95d0-bbf0f2cf15af',
  '6a40013f-6a52-40ee-9c44-6daecc86dfe5',
  '69988dc7-a073-45b8-a473-1d4b79170d86',
  'e901bdc7-b343-481c-b389-1fef9fba75b8',
  '4eb6d95b-7021-4dad-a192-0a96a1d037fb',
  'bfed38a3-8088-4241-9e08-07184ed9cb24',
  '24676ef5-88e4-4669-ae0a-926433c6c208',
  'caa9ea45-d95e-483e-9b8c-35a599840271',
  '932620dd-96f4-46ef-91a6-5225bb122068',
  '9e188c00-5af1-4b92-9c45-35a65a86d613',
  'da1886f0-2ac8-410e-9756-dd9e4dfb1398',
  '8e6cc7e1-e874-4075-8f00-a500951a4761',
  '45b3b9e0-a6d9-47b5-a062-34851cc539eb',
  '0f285841-6b22-42ae-ab4e-30ff252da587',
  '0403a711-bef2-423f-bbd5-ebf8a4b00220',
  '2470e4ea-bf45-4821-98fb-f660ff0eca14',
  'c77203ea-dff6-47f4-84b0-40bbd1d6b24c',
  '010cbdf6-3257-49dd-a07e-a607ad0100bd',
  '411aa343-7fe7-457a-91f0-696ec2a2cf60',
  '106f34da-080e-4ec6-91bd-f76bc5f15c69',
  '8cb45f73-7935-4e82-af8d-9ea5849461fb',
  'd9995e7f-68d1-424c-908b-5acfdfc832fd',
  '1230c1c6-b6c7-471a-afee-9742336d5989',
  '2133849d-9ef8-4993-9418-d912436fde7b',
  '35ca928f-6f3f-470a-bc3a-facc6b0bc344',
  '85266fa4-2693-4be0-a63d-336bec7604c0',
  '8d862689-fc7a-4270-853b-9c5b71dc9e87',
  'a737ba65-1c6e-4a82-9d0a-ffdbc5bf9112',
  '2a7b0133-bade-4497-a15c-843254cdaf8b',
  '466bb3ae-c42d-412e-819f-17bda1dceb21',
  '4c7c9674-2df9-4052-acae-3ae9856d5abb',
  'e8736b0a-2be8-4a54-ac09-a22eee520de1',
  '1ea543b2-7463-4d9d-8557-9495ff05e953',
  '64c13bcb-ee54-4f01-9854-35dcfc66d127',
  '496f3222-9190-44ac-a8d0-0a4427d97eba',
  'd72b1ff7-c9e7-4d62-b4ba-2817ff1a4c08',
  '25576979-cfec-44e7-86b1-ba901f9b1140',
  '4d2b45b9-f62c-452d-a93a-83f212270801',
  'e005783d-d01d-4cb6-bf50-6224a67335c2',
  '55cdea06-f918-4005-949b-297721c5c74d',
  '94eabe1e-447a-49a6-8f5a-efa9b5cb26e2',
  '279b080d-2542-4bbc-9809-8135423c13e2',
  '952ac781-2fea-4976-9daf-e50441bcc1aa',
  '04258e84-8d20-4ce6-89d3-e98cc086cc33',
  '272a6a0a-523f-4cd9-8d7f-8274e513fe12',
  '22ee5bca-49fd-437c-994b-47e275b00428',
  '7777d143-9e83-444b-b24f-b9c83f36a0e3',
  '6b195c88-d5d3-427d-907c-8ab008a506c3',
  '47669770-7e85-4fc8-a1ea-d02b2737eac9',
  '8708adc5-cffd-4d9d-a40e-5690069965b4',
  'c8ec1092-c874-4878-acca-0bda1d9739ec',
  'ad9e79f5-3157-4437-8bf7-45a4023e616f',
  '36c91889-2103-40eb-9e34-0ddcb1216891',
  '4ac1c898-b426-4e57-8877-287d521dac68',
  '25638550-9ab4-44b3-ae93-adefd48a6cea',
  'e7ed04d6-4351-4eb7-b43f-ef4ad7b19037',
  '362599ca-1021-4e1a-aac7-92b0372800a1',
  '8a1c6dea-e794-482b-84ea-d5397e331c2b',
  '01830b46-a44f-448e-8f8c-fb7a38549324',
  -- Pro-AI Entrepreneurs + Pro-Free Ventures sessions (shared bot, 26 sessions)
  'ae7686c5-8e24-40a9-ac40-8640e178f325',
  '6494b82f-ea25-4391-ad01-14e7196a9f72',
  '5cc3438b-5636-4741-b9b9-497bb6e8ddce',
  '1a17a829-f6f8-42bb-8683-e52d1063376e',
  'c567b289-8087-42da-aed6-392a3bf2715a',
  'd68e3217-8187-4643-9a7c-b8346e030e25',
  '97dd8210-ad8a-4568-9e54-ce92b91f7b45',
  '23a89920-34ec-49f3-96c9-16d29b60feb0',
  'b34b765f-ae96-415d-b8e3-adcb9a3ae30a',
  'e6c28bbf-c39c-43b7-920b-bcf073aa9520',
  'f09832e3-5cc2-4408-b9c5-9e0dc357e74a',
  'beb914c3-bd72-483a-a3ac-15a812f38f0a',
  'f72d0424-5286-4f30-aac1-c4042be95d55',
  'c1e78ad8-82e4-4d65-ac48-a936617d7106',
  'b4017290-721e-452f-b882-1c514ea464cb',
  '2aa05b08-6a9d-45a4-93af-b3ba0440b3e6',
  '2d36ee63-f1d6-494a-9dff-e0d40db72931',
  '46f2314d-1c2c-4c88-a208-24ec7ab94d0d',
  '0d52482d-51d5-4fc5-9686-40673ed23412',
  '09e5b394-6377-4871-a089-1d5e6d458320',
  'ebbebc23-20e4-4e9d-ab54-6996f0dc9d89',
  '41c80557-b754-43ec-8620-5aabd4a04c7a',
  '1eb2b7b5-3e99-46fe-bc72-744dfa807d4c',
  '4d055692-e674-4a83-9738-fbad6ca248f9',
  '0599ad18-4af2-4250-aa3d-a3b664316998',
  'c9bca700-c9d5-439c-b262-e2624d9c9896',
  -- Pro-Berkeley PBL (1 session, minor)
  'ca0ee12e-2d7f-4be0-95a2-eaae4ea77b93'
);

-- Step 2: Update all club ELOs (recalculated from 88,793 clean matchups, K=24)
UPDATE clubs SET elo_rating = 1670, wins = 1299, total_votes = 2524 WHERE id = '2540c96e-82bb-4fd5-87ae-5b9c3c733fc7'; -- Data Science Society
UPDATE clubs SET elo_rating = 1668, wins = 1173, total_votes = 2517 WHERE id = '03df4d5a-dd57-4a0a-a3e3-5373e27858a1'; -- Valley Consulting Group
UPDATE clubs SET elo_rating = 1623, wins = 1348, total_votes = 2548 WHERE id = 'f8fbf611-6450-437b-beda-28e794eea860'; -- BerkeleyTime
UPDATE clubs SET elo_rating = 1608, wins = 1317, total_votes = 2537 WHERE id = '5d9991d3-e31b-4b75-81b2-85e1ff9d4c6e'; -- DiversaTech
UPDATE clubs SET elo_rating = 1602, wins = 1198, total_votes = 2527 WHERE id = '423b2348-5499-49f2-a957-6dc8a608e096'; -- The Berkeley Group
UPDATE clubs SET elo_rating = 1598, wins = 1351, total_votes = 2522 WHERE id = '5500e44d-f7b1-4f57-ab2d-321bf0cb8d84'; -- Berkeley Consulting
UPDATE clubs SET elo_rating = 1594, wins = 1261, total_votes = 2550 WHERE id = 'aedd1a2e-a0ca-4012-a616-07d8ed67c396'; -- Machine Learning at Berkeley
UPDATE clubs SET elo_rating = 1590, wins = 1312, total_votes = 2527 WHERE id = '5b10fbe7-da5e-42d7-a3f8-c1dd85e8f86e'; -- Blueprint
UPDATE clubs SET elo_rating = 1578, wins = 1315, total_votes = 2538 WHERE id = '7cb9ca4e-85a9-4ecb-85a7-d66cf222453f'; -- Codebase
UPDATE clubs SET elo_rating = 1573, wins = 1158, total_votes = 2517 WHERE id = 'b7ff8c51-b104-45b1-8698-f59adc2defd5'; -- Venture Strategy Solutions
UPDATE clubs SET elo_rating = 1572, wins = 1286, total_votes = 2519 WHERE id = 'd3128e69-ed2e-4aa5-98b4-36880d43211e'; -- Codeology
UPDATE clubs SET elo_rating = 1568, wins = 1323, total_votes = 2497 WHERE id = '0e455f5c-44b0-43c1-8239-ff433dd9b749'; -- Calisthenics Club
UPDATE clubs SET elo_rating = 1561, wins = 1216, total_votes = 2529 WHERE id = 'd1f0ea40-1669-4239-9b5b-4b0b7d36f649'; -- Net Impact Berkeley
UPDATE clubs SET elo_rating = 1558, wins = 1277, total_votes = 2524 WHERE id = '5feb81f4-fa43-4850-b676-2ca60a58f135'; -- Camp Kesem Berkeley
UPDATE clubs SET elo_rating = 1557, wins = 1310, total_votes = 2546 WHERE id = 'd38dce85-cff1-4d04-85d8-3cbf7c5b852f'; -- Asian American Association
UPDATE clubs SET elo_rating = 1556, wins = 1208, total_votes = 2534 WHERE id = 'dcd972f1-c04c-4be3-ab17-a774d4de1ffa'; -- UpSync
UPDATE clubs SET elo_rating = 1554, wins = 1357, total_votes = 2527 WHERE id = 'afd51520-1820-48f8-8fb8-916ecc1430f7'; -- 180 Degrees Consulting
UPDATE clubs SET elo_rating = 1552, wins = 1176, total_votes = 2534 WHERE id = 'aaa8b94f-6df9-4a03-aa03-ea1b553345f4'; -- The Berkeley Forum
UPDATE clubs SET elo_rating = 1552, wins = 1333, total_votes = 2556 WHERE id = '0a7c464a-0ef5-4c78-8326-fcd9c0c86851'; -- Innovative Design
UPDATE clubs SET elo_rating = 1552, wins = 1384, total_votes = 2538 WHERE id = 'e3da9975-ef0b-4555-adf3-4a9ee9735270'; -- Ascend Berkeley
UPDATE clubs SET elo_rating = 1546, wins = 1208, total_votes = 2538 WHERE id = '07168e84-f448-448e-b5f5-c11dce940fd9'; -- Traders at Berkeley
UPDATE clubs SET elo_rating = 1545, wins = 1287, total_votes = 2540 WHERE id = '058dcdac-2a5f-482b-b2a1-4ae86664d34c'; -- Furries at Berkeley
UPDATE clubs SET elo_rating = 1534, wins = 11, total_votes = 17 WHERE id = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97'; -- Blockchain
UPDATE clubs SET elo_rating = 1532, wins = 1329, total_votes = 2523 WHERE id = '0fea1fbe-34e0-47df-99d1-a9453d25225e'; -- Berkeley Innovation
UPDATE clubs SET elo_rating = 1531, wins = 1334, total_votes = 2544 WHERE id = '1c747a03-0e8f-48fa-a0b2-14ed169818b1'; -- BCEC
UPDATE clubs SET elo_rating = 1531, wins = 1308, total_votes = 2526 WHERE id = 'ae64b5e7-0fea-497a-bf64-4e79d15772f0'; -- Big Data at Berkeley
UPDATE clubs SET elo_rating = 1528, wins = 1171, total_votes = 2545 WHERE id = '67d7ab80-2204-427f-804a-1d98553bfdce'; -- Web Development at Berkeley
UPDATE clubs SET elo_rating = 1525, wins = 1204, total_votes = 2556 WHERE id = '5e974d3a-170e-4816-8c85-d2cc2ae59f1c'; -- Venture Capital at Berkeley
UPDATE clubs SET elo_rating = 1520, wins = 1328, total_votes = 2523 WHERE id = 'c3221797-d476-459b-8885-ce10be328f05'; -- AI Entrepreneurs at Berkeley
UPDATE clubs SET elo_rating = 1520, wins = 1347, total_votes = 2522 WHERE id = 'bdb3bc72-f439-4ed9-916b-4a98ae66f02c'; -- Berkeley Investment Group
UPDATE clubs SET elo_rating = 1512, wins = 1162, total_votes = 2552 WHERE id = 'fbdcde41-48ef-4568-b2fe-b4375b5d69d2'; -- Voyager Consulting
UPDATE clubs SET elo_rating = 1509, wins = 1272, total_votes = 2523 WHERE id = 'd9e7b16f-45f2-40ea-91f2-f9cc4a70d2ad'; -- CMG Strategy Consulting
UPDATE clubs SET elo_rating = 1507, wins = 1282, total_votes = 2519 WHERE id = 'ea1331a3-64da-4fcc-b523-71bbc41467df'; -- Product Space
UPDATE clubs SET elo_rating = 1501, wins = 1341, total_votes = 2532 WHERE id = '2cb3dfd1-491c-4724-9f6c-641c17971b97'; -- BJJ at Berkeley
UPDATE clubs SET elo_rating = 1500, wins = 1377, total_votes = 2534 WHERE id = 'fb16d210-c0fe-4c3d-a6e2-57dd78b0baac'; -- BEACN
UPDATE clubs SET elo_rating = 1500, wins = 1282, total_votes = 2555 WHERE id = '45cadb5b-26f0-479c-a991-954bc56df93c'; -- Mobile Developers of Berkeley
UPDATE clubs SET elo_rating = 1492, wins = 1232, total_votes = 2552 WHERE id = 'bb35c455-b53f-4b78-bc01-c0e844158fb3'; -- Launchpad
UPDATE clubs SET elo_rating = 1489, wins = 1330, total_votes = 2529 WHERE id = '60dc17e3-5fbc-468d-ad1a-efba8b3d2cce'; -- Berkeley Business Society
UPDATE clubs SET elo_rating = 1488, wins = 1373, total_votes = 2548 WHERE id = '7b99f196-fd84-4144-a429-2ee5d1d3774a'; -- ANova
UPDATE clubs SET elo_rating = 1484, wins = 1319, total_votes = 2543 WHERE id = '75462235-53ae-4318-9df1-7c5b09a83456'; -- Berkeley PBL
UPDATE clubs SET elo_rating = 1482, wins = 1223, total_votes = 2534 WHERE id = '9a24dd5f-6f23-45c6-b275-60ff9488df3b'; -- Theta Tau
UPDATE clubs SET elo_rating = 1478, wins = 1186, total_votes = 2533 WHERE id = '7164db38-440f-4abb-bb27-5396db0d0f6b'; -- Undergraduate Finance Association
UPDATE clubs SET elo_rating = 1477, wins = 1281, total_votes = 2563 WHERE id = '6734856d-12c3-4d49-9d80-e9cd9de9fe7f'; -- HBSA
UPDATE clubs SET elo_rating = 1476, wins = 1253, total_votes = 2547 WHERE id = '18db0409-32b9-4e32-9970-1068b9134f03'; -- Entrepreneurs @ Berkeley
UPDATE clubs SET elo_rating = 1475, wins = 1174, total_votes = 2519 WHERE id = '4c7cf139-33b6-4b7d-ba36-821a5282fbf6'; -- Undergraduate Real Estate Club
UPDATE clubs SET elo_rating = 1471, wins = 98, total_votes = 195 WHERE id = '82ce10eb-0da9-4c70-a8af-d3232e9af8ba'; -- Salsa at Cal
UPDATE clubs SET elo_rating = 1466, wins = 1188, total_votes = 2549 WHERE id = '3a462083-e72a-4bc3-990f-628e542e8248'; -- PlexTech
UPDATE clubs SET elo_rating = 1465, wins = 1280, total_votes = 2530 WHERE id = 'a418ea5d-e071-4266-99ef-a17fd69f8322'; -- Berkeley Finance Club
UPDATE clubs SET elo_rating = 1464, wins = 1213, total_votes = 2534 WHERE id = '99008bf3-96d6-4593-855d-e8e95c4319d6'; -- Global Research and Consulting
UPDATE clubs SET elo_rating = 1459, wins = 1335, total_votes = 2530 WHERE id = 'b1ffef9c-6df6-4ff4-a53a-0428d9042bf2'; -- Berkeley ABA
UPDATE clubs SET elo_rating = 1457, wins = 1198, total_votes = 2538 WHERE id = 'c0fd9308-4684-4dce-a3a0-0e3c68e4f407'; -- Women on Wall Street
UPDATE clubs SET elo_rating = 1456, wins = 1273, total_votes = 2513 WHERE id = 'd161bfc7-211f-4487-a418-a3544c142de7'; -- Capital Investments at Berkeley
UPDATE clubs SET elo_rating = 1453, wins = 1233, total_votes = 2508 WHERE id = '174d7ac8-471d-408f-9f0b-0d5a724f7c75'; -- Free Ventures
UPDATE clubs SET elo_rating = 1453, wins = 1232, total_votes = 2527 WHERE id = 'da09bbb7-5d30-4e8a-95f7-336638266d8f'; -- Next Generation Consulting
UPDATE clubs SET elo_rating = 1447, wins = 1290, total_votes = 2541 WHERE id = '62134dd5-d74a-4728-8629-c1054a35fae7'; -- Blackskies Investments
UPDATE clubs SET elo_rating = 1446, wins = 1213, total_votes = 2496 WHERE id = '993463c4-62c9-479b-af95-aa5277867eed'; -- SBC Strategy Consulting
UPDATE clubs SET elo_rating = 1445, wins = 1224, total_votes = 2499 WHERE id = '7f5c9ae4-85ea-4dca-86c8-3d25cb2de86a'; -- Phoenix Consulting Group
UPDATE clubs SET elo_rating = 1442, wins = 1198, total_votes = 2547 WHERE id = 'e7768c68-727a-4b00-9a8c-baadc9229144'; -- SAAS
UPDATE clubs SET elo_rating = 1440, wins = 1230, total_votes = 2520 WHERE id = '0ebc164b-61e9-4fb4-93c4-5674bacfd00b'; -- Nova Consulting
UPDATE clubs SET elo_rating = 1440, wins = 1252, total_votes = 2553 WHERE id = 'e8f8d8b3-d62e-42aa-9e1e-1590c8749d48'; -- Paws for Mental Health
UPDATE clubs SET elo_rating = 1440, wins = 1306, total_votes = 2549 WHERE id = '8a36a4a8-db9c-425e-a37f-c39b35abedc6'; -- CalTV
UPDATE clubs SET elo_rating = 1434, wins = 1260, total_votes = 2551 WHERE id = 'f38df864-8e8d-4532-bf56-96c381f5131f'; -- Consult Your Community
UPDATE clubs SET elo_rating = 1432, wins = 1171, total_votes = 2508 WHERE id = 'a6b80921-dedb-4987-9855-90de91f0ae6f'; -- Undergraduate Marketing Association
UPDATE clubs SET elo_rating = 1424, wins = 1233, total_votes = 2527 WHERE id = '88e85321-7ceb-4c63-9f52-8e1b23125e27'; -- Delta Consulting
UPDATE clubs SET elo_rating = 1424, wins = 1195, total_votes = 2515 WHERE id = 'c31aae7f-b700-4d81-b6b3-de1684de1c55'; -- Pi Sigma Epsilon
UPDATE clubs SET elo_rating = 1418, wins = 1332, total_votes = 2538 WHERE id = 'd58f879c-8cf8-43db-830d-2c10e8bb522b'; -- Beta Alpha Psi
UPDATE clubs SET elo_rating = 1402, wins = 1290, total_votes = 2542 WHERE id = 'd21299a6-3dd8-44bb-874d-be7d272280f4'; -- Healthcare Consulting Group
UPDATE clubs SET elo_rating = 1401, wins = 1223, total_votes = 2533 WHERE id = '1b26f411-9154-4a70-b71c-7eaaf9c2a89c'; -- imagiCal
UPDATE clubs SET elo_rating = 1377, wins = 1289, total_votes = 2548 WHERE id = 'fd040ee4-efd4-47c2-a2d2-ef77fd504a76'; -- Latinx Business Student Association
UPDATE clubs SET elo_rating = 1370, wins = 1262, total_votes = 2534 WHERE id = 'ef2b8429-dc06-47ad-be45-88ffee59c58b'; -- Microfinance at Berkeley
UPDATE clubs SET elo_rating = 1369, wins = 1162, total_votes = 2549 WHERE id = '8f20ef85-d269-47d9-99e2-8d5d42e87999'; -- Scholars of Finance
UPDATE clubs SET elo_rating = 1337, wins = 1397, total_votes = 2584 WHERE id = '82923e22-d368-4dd4-bcd0-22d885635bbb'; -- Alpha Epsilon Zeta

COMMIT;
