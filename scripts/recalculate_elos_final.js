/**
 * Final ELO recalculation after removing all targeted bot sessions.
 * Fetches remaining clean matchups (excluding targeted bot sessions),
 * replays ELO from scratch, and outputs SQL UPDATE statements.
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkdXRxdW1wbWJzb3FubGF0bG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTY4NjAsImV4cCI6MjA4NTI3Mjg2MH0.3fY59m59vs1O6QmAC2Fx47itJLJkyAWb6Q25gEsa_Uk';
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
const K_FACTOR = 24;

// Bot sessions to exclude
const BOT_SESSIONS = new Set([
  '091736c7-dc11-4505-9fe1-cdd0ae9c198d',
  '17e6dcad-664f-4504-970d-be80e1be45e3',
  'f3ce57ab-892d-45ce-ab45-bd5733beb565',
  '2ffe3ea2-5ac0-48a0-9e80-b7fa1c72ec01',
  'c7c2bc4b-adf0-4468-a8fe-ceb75ad68f6f',
  '6800989c-7a09-4c1d-87a7-8879463f7c4a',
  '77fdeec4-6f62-4eee-b3db-6ce4c000e59c',
  'fb31044f-7301-4928-b513-38566261af3a',
  '6b98bb82-7a94-4f79-9cbb-dab5fdb3d4d0',
  '1b0734fe-e220-410a-8377-44cf82e08c86',
  '05402635-1418-4529-bebe-67a7f2a78492',
  '7d85358d-80eb-442f-a84c-fc0411803914',
  '9893836d-b65f-4f78-b85d-8a784510c8d3',
  '3f54e4b8-e3fa-415e-9daa-a19cce063b50',
  '0ca9b06e-d8b3-4bb1-a8e3-53d92c874676',
  '286b9128-2b87-46e8-9a2c-7a9797180adb',
]);

// Known bot IP
const BOT_IPS = new Set(['107.21.89.25']);

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

  // Filter out bot sessions and bot IPs
  const clean = allMatchups.filter(m =>
    !BOT_SESSIONS.has(m.session_id) &&
    !BOT_IPS.has(m.ip_address)
  );
  process.stderr.write(`Clean matchups: ${clean.length} (removed ${allMatchups.length - clean.length})\n`);

  // Fetch clubs
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

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

  // Output SQL UPDATE statements
  console.log('-- ELO updates after removing targeted bot sessions');
  console.log('-- Clean matchups: ' + clean.length);
  console.log('');

  const sorted = clubs.sort((a, b) => (elos[b.id] || 1500) - (elos[a.id] || 1500));
  for (const c of sorted) {
    console.log(`UPDATE clubs SET elo_rating = ${elos[c.id]}, wins = ${wins[c.id]}, total_votes = ${totalVotes[c.id]} WHERE id = '${c.id}'; -- ${c.name}`);
  }

  // Print ranking table to stderr
  process.stderr.write('\n=== FINAL RANKINGS ===\n');
  process.stderr.write(`${'Club'.padEnd(40)} ${'ELO'.padStart(6)} ${'Votes'.padStart(8)} ${'Wins'.padStart(8)}\n`);
  process.stderr.write('-'.repeat(64) + '\n');
  for (const c of sorted) {
    process.stderr.write(`${c.name.padEnd(40)} ${String(elos[c.id]).padStart(6)} ${String(totalVotes[c.id]).padStart(8)} ${String(wins[c.id]).padStart(8)}\n`);
  }
}

main().catch(console.error);
