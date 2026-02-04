/**
 * Deep analysis of Blockchain's remaining matchups to find residual botting
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkdXRxdW1wbWJzb3FubGF0bG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTY4NjAsImV4cCI6MjA4NTI3Mjg2MH0.3fY59m59vs1O6QmAC2Fx47itJLJkyAWb6Q25gEsa_Uk';
const HEADERS = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
const BLOCKCHAIN_ID = '45b6bc20-aa8b-4100-ac9e-d20140c2ab97';

async function fetchAll(baseUrl) {
  const all = [];
  let offset = 0;
  while (true) {
    const res = await fetch(baseUrl + `&offset=${offset}&limit=1000`, { headers: HEADERS });
    const batch = await res.json();
    if (batch.length === 0) break;
    all.push(...batch);
    offset += 1000;
  }
  return all;
}

async function main() {
  // Get all remaining Blockchain matchups
  const matchups = await fetchAll(
    `${SUPABASE_URL}/rest/v1/matchups?select=*&or=(club_a_id.eq.${BLOCKCHAIN_ID},club_b_id.eq.${BLOCKCHAIN_ID})&order=created_at.asc`
  );

  console.log('Total remaining Blockchain matchups:', matchups.length);

  const wins = matchups.filter(m => m.winner_id === BLOCKCHAIN_ID).length;
  const losses = matchups.filter(m => m.winner_id !== null && m.winner_id !== BLOCKCHAIN_ID).length;
  console.log(`Wins: ${wins}, Losses: ${losses}, Win rate: ${(wins / (wins + losses) * 100).toFixed(1)}%`);

  // Group by session - check total session size (not just BC matchups)
  const sessionIds = [...new Set(matchups.map(m => m.session_id))];
  console.log(`\nUnique sessions voting on Blockchain: ${sessionIds.length}`);

  // For each session, count total votes in that session (not just BC ones)
  // and check if the session looks like a targeted Blockchain booster
  const bcBySession = {};
  for (const m of matchups) {
    if (!bcBySession[m.session_id]) bcBySession[m.session_id] = [];
    bcBySession[m.session_id].push(m);
  }

  // Sessions where BC appears 3+ times and wins every time
  const alwaysWinSessions = [];
  for (const [sessId, votes] of Object.entries(bcBySession)) {
    if (votes.length >= 3) {
      const bcWins = votes.filter(v => v.winner_id === BLOCKCHAIN_ID).length;
      if (bcWins === votes.length) {
        alwaysWinSessions.push({ sessId, count: votes.length, bcWins });
      }
    }
  }

  console.log(`Sessions where Blockchain wins ALL matchups (3+ matchups): ${alwaysWinSessions.length}`);
  alwaysWinSessions.sort((a, b) => b.count - a.count);
  for (const s of alwaysWinSessions.slice(0, 15)) {
    const votes = bcBySession[s.sessId];
    const fps = [...new Set(votes.map(v => v.fingerprint).filter(Boolean))];
    const ips = [...new Set(votes.map(v => v.ip_address).filter(Boolean))];
    const times = votes.map(v => new Date(v.created_at).getTime()).sort();
    const avgInt = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;
    console.log(`  ${s.sessId}: ${s.count} BC matchups, all wins | avg ${avgInt.toFixed(1)}s | FP: ${fps} | IP: ${ips}`);
  }

  // Fingerprint analysis: which fingerprints have high BC win rates?
  const byFP = {};
  for (const m of matchups) {
    const fp = m.fingerprint || 'null';
    if (!byFP[fp]) byFP[fp] = { total: 0, bcWins: 0, sessions: new Set() };
    byFP[fp].total++;
    byFP[fp].sessions.add(m.session_id);
    if (m.winner_id === BLOCKCHAIN_ID) byFP[fp].bcWins++;
  }

  console.log(`\nFingerprints voting on Blockchain: ${Object.keys(byFP).length}`);

  const suspiciousFPs = Object.entries(byFP)
    .filter(([_, v]) => v.total >= 3 && v.bcWins / v.total > 0.85)
    .sort((a, b) => b[1].total - a[1].total);

  console.log(`Fingerprints with 85%+ BC win rate (3+ votes):`);
  for (const [fp, v] of suspiciousFPs) {
    console.log(`  ${fp}: ${v.total} votes, ${v.bcWins} BC wins (${(v.bcWins / v.total * 100).toFixed(0)}%), ${v.sessions.size} sessions`);
  }

  // Now check: what does the full session look like for these suspicious fingerprints?
  // Pull ALL matchups for the top suspicious sessions
  console.log('\n--- Checking full session context for suspicious fingerprints ---');
  const topSuspFPs = suspiciousFPs.slice(0, 5).map(([fp]) => fp);
  for (const fp of topSuspFPs) {
    const fpInfo = byFP[fp];
    console.log(`\nFingerprint: ${fp} (${fpInfo.total} BC votes, ${fpInfo.bcWins} wins, ${fpInfo.sessions.size} sessions)`);

    // For each session of this FP, fetch total session votes
    for (const sessId of [...fpInfo.sessions].slice(0, 3)) {
      const sessRes = await fetch(
        `${SUPABASE_URL}/rest/v1/matchups?select=*&session_id=eq.${sessId}&order=created_at.asc&limit=1000`,
        { headers: HEADERS }
      );
      const sessVotes = await sessRes.json();
      const bcInSess = sessVotes.filter(v => v.club_a_id === BLOCKCHAIN_ID || v.club_b_id === BLOCKCHAIN_ID);
      const bcWinsInSess = bcInSess.filter(v => v.winner_id === BLOCKCHAIN_ID).length;
      const times = sessVotes.map(v => new Date(v.created_at).getTime()).sort();
      const avgInt = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;

      console.log(`  Session ${sessId}: ${sessVotes.length} total votes, ${bcInSess.length} BC matchups (${bcWinsInSess} BC wins), avg ${avgInt.toFixed(1)}s`);
    }
  }

  // Distribution analysis: what's a normal win rate for a popular club?
  console.log('\n--- Overall BC matchup timeline ---');
  // Group by day
  const byDay = {};
  for (const m of matchups) {
    const day = m.created_at.substring(0, 10);
    if (!byDay[day]) byDay[day] = { total: 0, wins: 0 };
    byDay[day].total++;
    if (m.winner_id === BLOCKCHAIN_ID) byDay[day].wins++;
  }

  for (const [day, v] of Object.entries(byDay).sort()) {
    const rate = v.total > 0 ? (v.wins / v.total * 100).toFixed(0) : 0;
    console.log(`  ${day}: ${v.total} matchups, ${v.wins} BC wins (${rate}%)`);
  }
}

main().catch(console.error);
