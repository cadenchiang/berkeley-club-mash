/**
 * Phase 4 ELO recalculation: remove remaining noise-bot sessions.
 * These are sessions with high-speed voting (avg <4s, 10+ votes),
 * large random sessions (50+ votes, <15s avg), and suspicious
 * multi-session fingerprints (200+ votes across 5+ sessions).
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY;
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
const K_FACTOR = 24;

const BOT_SESSIONS = new Set([
  '033f25fa-d55b-4990-8ad0-d336ec2a8c50',
  '041eef1f-3a6f-4317-aabc-110f7dcf9fdf',
  '04a45179-0aed-4e9f-ae84-1b657a7f8bcc',
  '1a186168-32bf-460f-a689-aa2c2d2a6da9',
  '1eeb84de-051c-4bb4-9fed-f2907487c204',
  '2b2ba603-0849-4556-8be1-5342fbae9e4c',
  '37c34c4f-c94f-4b28-b5a4-45cd47f4852f',
  '3f22a6fe-3cc9-458d-bf87-6efafee53b36',
  '44f70bc9-00de-4888-863d-004797bd31b8',
  '48373d1e-425d-4756-b25b-3326e908ce85',
  '55847cb2-23b4-4fbc-aaf5-b0e362697246',
  '567636bb-2d1a-4334-b8db-624a858bad6c',
  '5ae87682-584f-4bc3-b5c6-234eddeaf763',
  '5f1603a7-f2e0-4a92-a776-48057b2cca6e',
  '6126f8fa-f70d-4712-8cf4-8ce63d4baf07',
  '6fb10dd4-604d-4a63-a6c4-e95768740eda',
  '7ca2311b-fd16-4004-b573-5b2a110d20aa',
  '7cf9afaa-a2a2-419b-9afc-8a93bdd6a38f',
  '7f99b0a7-f12e-4983-a502-1615a75f6f1c',
  '82213936-3a29-4259-a364-fb386232c571',
  '83bfe561-c798-4dc8-9254-7676b33d1c86',
  '8e04f8a4-f6c7-430b-af48-72d606c9f9b6',
  '9a1ca06a-a07d-4082-a3e6-a0ed934dc08d',
  'a2e37e8e-3b07-429a-bd04-960219050f10',
  'ab94716e-7dfe-4e42-be0b-b808b30d0606',
  'b51d9fdf-c167-4647-8c24-dce4a4d1cc94',
  'bebc6bb0-6515-4996-8c3d-32e9e4281d12',
  'bf330e73-e18d-43b9-9528-77b6194f2759',
  'bf3e07eb-6309-4a00-a9a7-f33fbf1da3da',
  'c2b96a93-5713-4299-aaf4-87ec4c8b200c',
  'c9b38068-23f2-4107-b842-29d0825a3da8',
  'd298fae3-827c-4d18-9b52-6dc5c2c2d568',
  'd3575dd9-191a-46b6-9093-6b0df2cd804b',
  'd67d6b4a-4b91-4daf-b31c-fe25069d37f0',
  'd7bd37e9-e880-44df-b13e-0112c0226179',
  'eb150e88-fb7d-4410-afd4-310654e9bc64',
  'efee8f39-b059-4b9d-9abb-b6a4226a4387',
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
  process.stderr.write(`Total: ${allMatchups.length}\n`);

  const clean = allMatchups.filter(m => !BOT_SESSIONS.has(m.session_id));
  process.stderr.write(`Clean: ${clean.length} (removed ${allMatchups.length - clean.length})\n`);

  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();

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
    const expected = 1.0 / (1.0 + Math.pow(10.0, (loserElo - winnerElo) / 400.0));
    elos[winnerId] = Math.max(100, Math.min(3000, Math.round(winnerElo + K_FACTOR * (1.0 - expected))));
    elos[loserId] = Math.max(100, Math.min(3000, Math.round(loserElo + K_FACTOR * (0.0 - (1.0 - expected)))));
    wins[winnerId]++;
    totalVotes[winnerId]++;
    totalVotes[loserId]++;
  }

  const sorted = clubs.sort((a, b) => (elos[b.id] || 1500) - (elos[a.id] || 1500));
  for (const c of sorted) {
    console.log(`UPDATE clubs SET elo_rating = ${elos[c.id]}, wins = ${wins[c.id]}, total_votes = ${totalVotes[c.id]} WHERE id = '${c.id}'; -- ${c.name}`);
  }

  process.stderr.write('\n=== FINAL RANKINGS ===\n');
  process.stderr.write(`${'Club'.padEnd(40)} ${'ELO'.padStart(6)} ${'Votes'.padStart(8)} ${'Wins'.padStart(8)} ${'Win%'.padStart(6)}\n`);
  process.stderr.write('-'.repeat(70) + '\n');
  for (const c of sorted) {
    const wr = totalVotes[c.id] > 0 ? (wins[c.id] / totalVotes[c.id] * 100).toFixed(1) : '0.0';
    process.stderr.write(`${c.name.padEnd(40)} ${String(elos[c.id]).padStart(6)} ${String(totalVotes[c.id]).padStart(8)} ${String(wins[c.id]).padStart(8)} ${wr.padStart(5)}%\n`);
  }
}

main().catch(console.error);
