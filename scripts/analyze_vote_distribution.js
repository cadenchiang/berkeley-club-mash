/**
 * Analyze the raw matchup data to understand what's really going on.
 * Look at total vote counts per club vs what random pairing should produce.
 * Check if specific clubs are appearing far more often than expected.
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkdXRxdW1wbWJzb3FubGF0bG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTY4NjAsImV4cCI6MjA4NTI3Mjg2MH0.3fY59m59vs1O6QmAC2Fx47itJLJkyAWb6Q25gEsa_Uk';
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };

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
  // Fetch clubs
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

  console.log('Fetching all remaining matchups...');
  const allMatchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  console.log(`Total matchups: ${allMatchups.length}`);

  // Count appearances and wins per club
  const appearances = {};
  const wins = {};
  for (const c of clubs) {
    appearances[c.id] = 0;
    wins[c.id] = 0;
  }
  for (const m of allMatchups) {
    appearances[m.club_a_id] = (appearances[m.club_a_id] || 0) + 1;
    appearances[m.club_b_id] = (appearances[m.club_b_id] || 0) + 1;
    if (m.winner_id) wins[m.winner_id] = (wins[m.winner_id] || 0) + 1;
  }

  // Expected: each matchup involves 2 clubs out of 72
  // Total club-appearances = 2 * total_matchups = 2 * 88793 = 177586
  // Expected per club = 177586 / 72 = ~2466
  const totalAppearances = Object.values(appearances).reduce((a, b) => a + b, 0);
  const expectedPerClub = totalAppearances / clubs.length;
  console.log(`\nTotal club-appearances: ${totalAppearances}`);
  console.log(`Expected per club (uniform): ${expectedPerClub.toFixed(0)}`);

  // Show distribution
  const sorted = clubs.sort((a, b) => appearances[b.id] - appearances[a.id]);
  console.log(`\n${'Club'.padEnd(40)} ${'Appear'.padStart(7)} ${'Wins'.padStart(6)} ${'WinRate'.padStart(8)} ${'Ratio'.padStart(6)}`);
  console.log('-'.repeat(70));
  for (const c of sorted) {
    const ratio = (appearances[c.id] / expectedPerClub).toFixed(2);
    const winRate = appearances[c.id] > 0 ? (wins[c.id] / appearances[c.id] * 100).toFixed(1) : '0.0';
    const flag = appearances[c.id] > expectedPerClub * 1.3 ? ' <<<' : (appearances[c.id] < expectedPerClub * 0.7 ? ' !!!' : '');
    console.log(`${c.name.padEnd(40)} ${String(appearances[c.id]).padStart(7)} ${String(wins[c.id]).padStart(6)} ${(winRate + '%').padStart(8)} ${ratio.padStart(6)}${flag}`);
  }

  // Group by session and look at session sizes
  const bySession = {};
  for (const m of allMatchups) {
    if (!bySession[m.session_id]) bySession[m.session_id] = [];
    bySession[m.session_id].push(m);
  }
  const sessionSizes = Object.values(bySession).map(v => v.length).sort((a, b) => b - a);
  console.log(`\nTotal sessions: ${sessionSizes.length}`);
  console.log(`Largest sessions: ${sessionSizes.slice(0, 20).join(', ')}`);
  console.log(`Median session size: ${sessionSizes[Math.floor(sessionSizes.length / 2)]}`);

  // Check for sessions with biased club appearances
  // In a fair system with 72 clubs, each matchup has a club appearing by chance ~2.8%
  // So in a 100-vote session, a club should appear ~2.8 times
  console.log('\n=== Sessions where a single club appears in 30%+ of matchups (3+ votes) ===');
  let totalBiasedVotes = 0;
  const biasedSessions = [];
  for (const [sessId, votes] of Object.entries(bySession)) {
    if (votes.length < 5) continue;
    const clubCounts = {};
    for (const v of votes) {
      clubCounts[v.club_a_id] = (clubCounts[v.club_a_id] || 0) + 1;
      clubCounts[v.club_b_id] = (clubCounts[v.club_b_id] || 0) + 1;
    }
    for (const [clubId, count] of Object.entries(clubCounts)) {
      const rate = count / votes.length;
      if (rate >= 0.30 && count >= 5) {
        const clubWins = votes.filter(v => v.winner_id === clubId).length;
        biasedSessions.push({
          sessId, clubId, clubName: clubNames[clubId] || clubId,
          totalVotes: votes.length, clubAppearances: count, rate,
          clubWins, winRate: clubWins / count,
        });
        totalBiasedVotes += votes.length;
        break;
      }
    }
  }
  console.log(`Biased sessions: ${biasedSessions.length}, total votes: ${totalBiasedVotes}`);
  biasedSessions.sort((a, b) => b.totalVotes - a.totalVotes);
  for (const s of biasedSessions.slice(0, 30)) {
    console.log(`  ${s.sessId}: ${s.totalVotes} votes, ${s.clubName} in ${s.clubAppearances} (${(s.rate*100).toFixed(0)}%), wins ${s.clubWins}/${s.clubAppearances} (${(s.winRate*100).toFixed(0)}%)`);
  }

  // Check overall win rate distribution - are any clubs winning way more than 50%?
  console.log('\n=== Clubs with win rate > 55% or < 45% (potential remaining manipulation) ===');
  for (const c of sorted) {
    if (appearances[c.id] < 100) continue;
    const winRate = wins[c.id] / appearances[c.id];
    if (winRate > 0.55 || winRate < 0.45) {
      console.log(`  ${c.name}: ${(winRate*100).toFixed(1)}% win rate (${wins[c.id]}/${appearances[c.id]})`);
    }
  }
}

main().catch(console.error);
