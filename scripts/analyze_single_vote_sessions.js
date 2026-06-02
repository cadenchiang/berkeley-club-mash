/**
 * Compare win rates between single-vote sessions and multi-vote human sessions.
 * If single-vote sessions show compressed/uniform win rates compared to
 * multi-vote human sessions, they're likely bot noise.
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY;
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
const K_FACTOR = 24;

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

function replayElo(matchups, clubs) {
  const elos = {};
  const wins = {};
  const totalVotes = {};
  for (const c of clubs) { elos[c.id] = 1500; wins[c.id] = 0; totalVotes[c.id] = 0; }
  for (const m of matchups) {
    if (!m.winner_id) continue;
    const wId = m.winner_id;
    const lId = m.club_a_id === wId ? m.club_b_id : m.club_a_id;
    if (elos[wId] === undefined || elos[lId] === undefined) continue;
    const exp = 1.0 / (1.0 + Math.pow(10.0, (elos[lId] - elos[wId]) / 400.0));
    elos[wId] = Math.max(100, Math.min(3000, Math.round(elos[wId] + K_FACTOR * (1.0 - exp))));
    elos[lId] = Math.max(100, Math.min(3000, Math.round(elos[lId] + K_FACTOR * (0.0 - (1.0 - exp)))));
    wins[wId]++; totalVotes[wId]++; totalVotes[lId]++;
  }
  return { elos, wins, totalVotes };
}

async function main() {
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

  console.log('Fetching all matchups...');
  const allMatchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  console.log(`Total: ${allMatchups.length}`);

  // Group by session
  const bySession = {};
  for (const m of allMatchups) {
    if (!bySession[m.session_id]) bySession[m.session_id] = [];
    bySession[m.session_id].push(m);
  }

  // Split into single-vote vs multi-vote
  const singleVoteMatchups = [];
  const multiVoteMatchups = [];
  for (const [sessId, votes] of Object.entries(bySession)) {
    if (votes.length === 1) {
      singleVoteMatchups.push(...votes);
    } else {
      multiVoteMatchups.push(...votes);
    }
  }

  console.log(`Single-vote sessions: ${singleVoteMatchups.length} matchups`);
  console.log(`Multi-vote sessions: ${multiVoteMatchups.length} matchups`);

  // Win rate comparison
  const singleWins = {};
  const singleAppearances = {};
  const multiWins = {};
  const multiAppearances = {};
  for (const c of clubs) {
    singleWins[c.id] = 0; singleAppearances[c.id] = 0;
    multiWins[c.id] = 0; multiAppearances[c.id] = 0;
  }

  for (const m of singleVoteMatchups) {
    singleAppearances[m.club_a_id]++;
    singleAppearances[m.club_b_id]++;
    if (m.winner_id) singleWins[m.winner_id]++;
  }
  for (const m of multiVoteMatchups) {
    multiAppearances[m.club_a_id]++;
    multiAppearances[m.club_b_id]++;
    if (m.winner_id) multiWins[m.winner_id]++;
  }

  // Compare win rates
  console.log(`\n${'Club'.padEnd(40)} ${'Single%'.padStart(8)} ${'Multi%'.padStart(8)} ${'Diff'.padStart(6)} ${'S_n'.padStart(6)} ${'M_n'.padStart(6)}`);
  console.log('-'.repeat(78));

  const diffs = [];
  for (const c of clubs) {
    const sWR = singleAppearances[c.id] > 0 ? singleWins[c.id] / singleAppearances[c.id] : 0;
    const mWR = multiAppearances[c.id] > 0 ? multiWins[c.id] / multiAppearances[c.id] : 0;
    diffs.push({ id: c.id, name: c.name, sWR, mWR, diff: mWR - sWR, sN: singleAppearances[c.id], mN: multiAppearances[c.id] });
  }
  diffs.sort((a, b) => b.mWR - a.mWR);

  for (const d of diffs) {
    if (d.mN < 10) continue;
    console.log(`${d.name.padEnd(40)} ${(d.sWR * 100).toFixed(1).padStart(7)}% ${(d.mWR * 100).toFixed(1).padStart(7)}% ${(d.diff > 0 ? '+' : '') + (d.diff * 100).toFixed(1).padStart(5)}  ${String(d.sN).padStart(5)} ${String(d.mN).padStart(5)}`);
  }

  // Statistical test: correlation between single-vote WR and multi-vote WR
  const validClubs = diffs.filter(d => d.mN >= 50 && d.sN >= 100);
  const sWRs = validClubs.map(d => d.sWR);
  const mWRs = validClubs.map(d => d.mWR);

  const sAvg = sWRs.reduce((a, b) => a + b, 0) / sWRs.length;
  const mAvg = mWRs.reduce((a, b) => a + b, 0) / mWRs.length;
  let num = 0, denS = 0, denM = 0;
  for (let i = 0; i < sWRs.length; i++) {
    num += (sWRs[i] - sAvg) * (mWRs[i] - mAvg);
    denS += (sWRs[i] - sAvg) ** 2;
    denM += (mWRs[i] - mAvg) ** 2;
  }
  const corr = num / Math.sqrt(denS * denM);

  console.log(`\nCorrelation between single-vote WR and multi-vote WR: ${corr.toFixed(3)}`);
  console.log(`Single-vote WR range: ${(Math.min(...sWRs)*100).toFixed(1)}% - ${(Math.max(...sWRs)*100).toFixed(1)}%`);
  console.log(`Multi-vote WR range: ${(Math.min(...mWRs)*100).toFixed(1)}% - ${(Math.max(...mWRs)*100).toFixed(1)}%`);

  // Replay ELO on multi-vote only
  console.log('\n=== ELO from multi-vote sessions only ===');
  const multiElo = replayElo(multiVoteMatchups, clubs);
  const sorted = [...clubs].sort((a, b) => (multiElo.elos[b.id] || 1500) - (multiElo.elos[a.id] || 1500));
  console.log(`${'Club'.padEnd(40)} ${'ELO'.padStart(6)} ${'Votes'.padStart(8)} ${'Wins'.padStart(8)} ${'Win%'.padStart(6)}`);
  console.log('-'.repeat(70));
  for (const c of sorted) {
    if (multiElo.totalVotes[c.id] < 10) continue;
    const wr = (multiElo.wins[c.id] / multiElo.totalVotes[c.id] * 100).toFixed(1);
    console.log(`${c.name.padEnd(40)} ${String(multiElo.elos[c.id]).padStart(6)} ${String(multiElo.totalVotes[c.id]).padStart(8)} ${String(multiElo.wins[c.id]).padStart(8)} ${wr.padStart(5)}%`);
  }

  const multiElos = Object.values(multiElo.elos).filter((_, i) => multiElo.totalVotes[clubs[i].id] >= 10);
  console.log(`\nMulti-vote ELO spread: ${Math.min(...multiElos)} - ${Math.max(...multiElos)} = ${Math.max(...multiElos) - Math.min(...multiElos)}`);

  // Output SQL for multi-vote ELO
  console.log('\n--- SQL UPDATE statements (multi-vote ELO) ---');
  for (const c of sorted) {
    console.log(`UPDATE clubs SET elo_rating = ${multiElo.elos[c.id]}, wins = ${multiElo.wins[c.id]}, total_votes = ${multiElo.totalVotes[c.id]} WHERE id = '${c.id}'; -- ${c.name}`);
  }
}

main().catch(console.error);
