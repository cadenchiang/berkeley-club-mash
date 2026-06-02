/**
 * Phase 3 ELO recalculation after removing all remaining bot sessions.
 * Excludes 101 bot sessions identified by deep analysis (50%+ appearance rate).
 * Outputs SQL UPDATE statements for migration.
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY;
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
const K_FACTOR = 24;

// All 101 bot sessions from deep analysis
const BOT_SESSIONS = new Set([
  '6bc8cb6a-bc12-440d-a477-068eba77bec2',
  'f3955be0-2aa5-4542-9d34-7b42358bb5a5',
  '7052d71e-d7cd-4fa5-8b5c-03f3b4458d68',
  '44e2931b-27ec-4bc0-aab5-ac00fce62c03',
  'ae7686c5-8e24-40a9-ac40-8640e178f325',
  '931e7108-d21e-4a37-9a4b-a4c791227d8d',
  '34e13382-884a-43d8-8db5-c8c82122e805',
  '6494b82f-ea25-4391-ad01-14e7196a9f72',
  '409cfdfc-ac57-4872-a07f-0fefcd357f52',
  'c4484dfd-a7ae-4fbd-8e75-44c3cd018003',
  '5cc3438b-5636-4741-b9b9-497bb6e8ddce',
  '1a17a829-f6f8-42bb-8683-e52d1063376e',
  'c567b289-8087-42da-aed6-392a3bf2715a',
  'd68e3217-8187-4643-9a7c-b8346e030e25',
  '97dd8210-ad8a-4568-9e54-ce92b91f7b45',
  '23a89920-34ec-49f3-96c9-16d29b60feb0',
  'a8fdef2f-5e7a-46ae-8acc-2ff6e687135e',
  'b34b765f-ae96-415d-b8e3-adcb9a3ae30a',
  '1ec3f1f4-191f-4c8f-8aa6-1b92c8a65f90',
  '8750b23b-30e2-4e7f-a974-056b3c49ed94',
  'e6c28bbf-c39c-43b7-920b-bcf073aa9520',
  '9ccb9b69-288f-4989-a13c-5cfc2dc57f48',
  'f09832e3-5cc2-4408-b9c5-9e0dc357e74a',
  'e8327368-5180-435c-8755-3d80fc6a6ab1',
  'beb914c3-bd72-483a-a3ac-15a812f38f0a',
  'f72d0424-5286-4f30-aac1-c4042be95d55',
  'c1e78ad8-82e4-4d65-ac48-a936617d7106',
  'b4017290-721e-452f-b882-1c514ea464cb',
  '454aaaed-5b9a-467b-911b-06c369b11c36',
  'a6236567-5887-4ee5-b363-b7ca04748290',
  '2aa05b08-6a9d-45a4-93af-b3ba0440b3e6',
  '37633d2d-d3c5-46e5-95d0-bbf0f2cf15af',
  '2d36ee63-f1d6-494a-9dff-e0d40db72931',
  '6a40013f-6a52-40ee-9c44-6daecc86dfe5',
  '46f2314d-1c2c-4c88-a208-24ec7ab94d0d',
  '69988dc7-a073-45b8-a473-1d4b79170d86',
  'e901bdc7-b343-481c-b389-1fef9fba75b8',
  '0d52482d-51d5-4fc5-9686-40673ed23412',
  '09e5b394-6377-4871-a089-1d5e6d458320',
  '4eb6d95b-7021-4dad-a192-0a96a1d037fb',
  'bfed38a3-8088-4241-9e08-07184ed9cb24',
  'ebbebc23-20e4-4e9d-ab54-6996f0dc9d89',
  '24676ef5-88e4-4669-ae0a-926433c6c208',
  'caa9ea45-d95e-483e-9b8c-35a599840271',
  '932620dd-96f4-46ef-91a6-5225bb122068',
  '41c80557-b754-43ec-8620-5aabd4a04c7a',
  '1eb2b7b5-3e99-46fe-bc72-744dfa807d4c',
  '9e188c00-5af1-4b92-9c45-35a65a86d613',
  '4d055692-e674-4a83-9738-fbad6ca248f9',
  'da1886f0-2ac8-410e-9756-dd9e4dfb1398',
  '0599ad18-4af2-4250-aa3d-a3b664316998',
  '8e6cc7e1-e874-4075-8f00-a500951a4761',
  '45b3b9e0-a6d9-47b5-a062-34851cc539eb',
  '0f285841-6b22-42ae-ab4e-30ff252da587',
  '0403a711-bef2-423f-bbd5-ebf8a4b00220',
  '2470e4ea-bf45-4821-98fb-f660ff0eca14',
  'c9bca700-c9d5-439c-b262-e2624d9c9896',
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
  'ca0ee12e-2d7f-4be0-95a2-eaae4ea77b93',
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
]);

async function fetchAll(baseUrl) {
  const all = [];
  let offset = 0;
  while (true) {
    const res = await fetch(baseUrl + `&offset=${offset}&limit=1000`, { headers: HEADERS });
    const batch = await res.json();
    if (batch.length === 0) break;
    all.push(...batch);
    offset += 1000;
    if (offset % 10000 === 0) process.stderr.write(`  Fetched ${all.length}...\n`);
  }
  return all;
}

async function main() {
  process.stderr.write('Fetching all matchups...\n');
  const allMatchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  process.stderr.write(`Total matchups: ${allMatchups.length}\n`);

  const clean = allMatchups.filter(m => !BOT_SESSIONS.has(m.session_id));
  process.stderr.write(`Clean matchups: ${clean.length} (removed ${allMatchups.length - clean.length})\n`);

  // Fetch clubs
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();

  // Replay ELO from scratch
  const elos = {};
  const wins = {};
  const totalVotes = {};
  for (const c of clubs) {
    elos[c.id] = 1500;
    wins[c.id] = 0;
    totalVotes[c.id] = 0;
  }

  for (const m of clean) {
    if (!m.winner_id) continue;
    const winnerId = m.winner_id;
    const loserId = m.club_a_id === winnerId ? m.club_b_id : m.club_a_id;
    if (elos[winnerId] === undefined || elos[loserId] === undefined) continue;

    const winnerElo = elos[winnerId];
    const loserElo = elos[loserId];
    const expectedWinner = 1.0 / (1.0 + Math.pow(10.0, (loserElo - winnerElo) / 400.0));
    elos[winnerId] = Math.max(100, Math.min(3000, Math.round(winnerElo + K_FACTOR * (1.0 - expectedWinner))));
    elos[loserId] = Math.max(100, Math.min(3000, Math.round(loserElo + K_FACTOR * (0.0 - (1.0 - expectedWinner)))));
    wins[winnerId] = (wins[winnerId] || 0) + 1;
    totalVotes[winnerId] = (totalVotes[winnerId] || 0) + 1;
    totalVotes[loserId] = (totalVotes[loserId] || 0) + 1;
  }

  // Output SQL
  console.log('-- Phase 3: ELO updates after removing all remaining bot sessions');
  console.log('-- Clean matchups: ' + clean.length);
  console.log('');

  const sorted = clubs.sort((a, b) => (elos[b.id] || 1500) - (elos[a.id] || 1500));
  for (const c of sorted) {
    console.log(`UPDATE clubs SET elo_rating = ${elos[c.id]}, wins = ${wins[c.id]}, total_votes = ${totalVotes[c.id]} WHERE id = '${c.id}'; -- ${c.name}`);
  }

  // Print ranking table
  process.stderr.write('\n=== FINAL RANKINGS ===\n');
  process.stderr.write(`${'Club'.padEnd(40)} ${'ELO'.padStart(6)} ${'Votes'.padStart(8)} ${'Wins'.padStart(8)} ${'Win%'.padStart(6)}\n`);
  process.stderr.write('-'.repeat(70) + '\n');
  for (const c of sorted) {
    const winRate = totalVotes[c.id] > 0 ? (wins[c.id] / totalVotes[c.id] * 100).toFixed(1) : '0.0';
    process.stderr.write(`${c.name.padEnd(40)} ${String(elos[c.id]).padStart(6)} ${String(totalVotes[c.id]).padStart(8)} ${String(wins[c.id]).padStart(8)} ${winRate.padStart(5)}%\n`);
  }

  // Sanity check: verify no club has extreme vote count disparity
  const voteCounts = Object.values(totalVotes).filter(v => v > 0);
  const medianVotes = voteCounts.sort((a, b) => a - b)[Math.floor(voteCounts.length / 2)];
  process.stderr.write(`\nMedian votes per club: ${medianVotes}\n`);
  process.stderr.write('Outlier check (>1.5x median):\n');
  for (const c of sorted) {
    if (totalVotes[c.id] > medianVotes * 1.5) {
      process.stderr.write(`  WARNING: ${c.name}: ${totalVotes[c.id]} votes (${(totalVotes[c.id] / medianVotes).toFixed(1)}x median)\n`);
    }
  }
}

main().catch(console.error);
