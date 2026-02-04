/**
 * Analyze large sessions. Real users probably vote 5-30 times.
 * Sessions with hundreds of votes are likely bots even if they
 * don't target a specific club.
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

  // Session size histogram
  const sizes = Object.values(bySession).map(v => v.length);
  const buckets = { '1': 0, '2-5': 0, '6-10': 0, '11-20': 0, '21-50': 0, '51-100': 0, '101-200': 0, '200+': 0 };
  const bucketVotes = { '1': 0, '2-5': 0, '6-10': 0, '11-20': 0, '21-50': 0, '51-100': 0, '101-200': 0, '200+': 0 };
  for (const s of sizes) {
    const key = s === 1 ? '1' : s <= 5 ? '2-5' : s <= 10 ? '6-10' : s <= 20 ? '11-20' : s <= 50 ? '21-50' : s <= 100 ? '51-100' : s <= 200 ? '101-200' : '200+';
    buckets[key]++;
    bucketVotes[key] += s;
  }
  console.log('\nSession size distribution:');
  console.log(`${'Size'.padEnd(12)} ${'Sessions'.padStart(10)} ${'Votes'.padStart(10)} ${'% of votes'.padStart(10)}`);
  for (const [key, count] of Object.entries(buckets)) {
    const votes = bucketVotes[key];
    const pct = (votes / allMatchups.length * 100).toFixed(1);
    console.log(`${key.padEnd(12)} ${String(count).padStart(10)} ${String(votes).padStart(10)} ${(pct + '%').padStart(10)}`);
  }

  // Analyze all sessions > 50 votes
  console.log('\n=== Sessions with 50+ votes ===');
  const largeSessions = Object.entries(bySession)
    .filter(([_, v]) => v.length >= 50)
    .sort((a, b) => b[1].length - a[1].length);

  for (const [sessId, votes] of largeSessions) {
    const times = votes.map(v => new Date(v.created_at).getTime()).sort();
    const avgInterval = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;
    const ips = [...new Set(votes.map(v => v.ip_address).filter(Boolean))];
    const fps = [...new Set(votes.map(v => v.fingerprint).filter(Boolean))];

    // Check club distribution
    const clubCounts = {};
    const clubWins = {};
    for (const v of votes) {
      clubCounts[v.club_a_id] = (clubCounts[v.club_a_id] || 0) + 1;
      clubCounts[v.club_b_id] = (clubCounts[v.club_b_id] || 0) + 1;
      if (v.winner_id) clubWins[v.winner_id] = (clubWins[v.winner_id] || 0) + 1;
    }
    const topClub = Object.entries(clubCounts).sort((a, b) => b[1] - a[1])[0];
    const topWinner = Object.entries(clubWins).sort((a, b) => b[1] - a[1])[0];
    const uniqueClubs = Object.keys(clubCounts).length;

    console.log(`  ${sessId}: ${votes.length} votes, avg ${avgInterval.toFixed(1)}s, ${uniqueClubs} clubs, IP: ${ips.slice(0,3).join(',')}, FP: ${fps.slice(0,2).join(',')}`);
    console.log(`    Top club: ${clubNames[topClub[0]] || topClub[0]} (${topClub[1]} appearances = ${(topClub[1]/votes.length*100).toFixed(0)}%)`);
    console.log(`    Top winner: ${clubNames[topWinner[0]] || topWinner[0]} (${topWinner[1]} wins)`);
    console.log(`    Time range: ${votes[0].created_at} to ${votes[votes.length-1].created_at}`);
  }

  // What fraction of all votes come from sessions > 50?
  const bigSessionVotes = largeSessions.reduce((a, [_, v]) => a + v.length, 0);
  console.log(`\nTotal votes from sessions > 50: ${bigSessionVotes} (${(bigSessionVotes/allMatchups.length*100).toFixed(1)}%)`);

  // Now check: what about sessions 20-50? Those could also be bots
  console.log('\n=== Sessions with 20-50 votes (sampling top 20) ===');
  const medSessions = Object.entries(bySession)
    .filter(([_, v]) => v.length >= 20 && v.length <= 50)
    .sort((a, b) => b[1].length - a[1].length);

  for (const [sessId, votes] of medSessions.slice(0, 20)) {
    const times = votes.map(v => new Date(v.created_at).getTime()).sort();
    const avgInterval = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;
    const clubCounts = {};
    for (const v of votes) {
      clubCounts[v.club_a_id] = (clubCounts[v.club_a_id] || 0) + 1;
      clubCounts[v.club_b_id] = (clubCounts[v.club_b_id] || 0) + 1;
    }
    const topClub = Object.entries(clubCounts).sort((a, b) => b[1] - a[1])[0];
    console.log(`  ${sessId}: ${votes.length} votes, avg ${avgInterval.toFixed(1)}s, top club: ${clubNames[topClub[0]] || topClub[0]} (${(topClub[1]/votes.length*100).toFixed(0)}%)`);
  }
}

main().catch(console.error);
