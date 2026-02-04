/**
 * Deep analysis of clubs with abnormal vote counts.
 * Identifies remaining bot sessions by looking at:
 * - Clubs with significantly more votes than the median
 * - Session patterns for those clubs (appearance rate, win rate)
 * - Vote timing patterns within sessions
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
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name,elo_rating,wins,total_votes&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

  // Compute median total_votes
  const voteCounts = clubs.map(c => c.total_votes).sort((a, b) => a - b);
  const median = voteCounts[Math.floor(voteCounts.length / 2)];
  const avg = voteCounts.reduce((a, b) => a + b, 0) / voteCounts.length;

  console.log(`Club count: ${clubs.length}`);
  console.log(`Median total_votes: ${median}, Avg: ${avg.toFixed(0)}`);
  console.log(`Min: ${voteCounts[0]}, Max: ${voteCounts[voteCounts.length - 1]}`);

  // Flag clubs with significantly more votes than expected
  const outlierThreshold = median * 1.5;
  const outliers = clubs.filter(c => c.total_votes > outlierThreshold).sort((a, b) => b.total_votes - a.total_votes);
  console.log(`\nOutlier clubs (>${outlierThreshold} votes):`);
  for (const c of outliers) {
    const winRate = (c.wins / c.total_votes * 100).toFixed(1);
    console.log(`  ${c.name}: ${c.total_votes} votes, ${c.wins} wins (${winRate}%), ELO ${c.elo_rating}`);
  }

  // Also check clubs with unusually high win rates (even with normal vote counts)
  console.log(`\nClubs with >60% win rate:`);
  for (const c of clubs.sort((a, b) => (b.wins / b.total_votes) - (a.wins / a.total_votes))) {
    const winRate = c.wins / c.total_votes;
    if (winRate > 0.60 && c.total_votes > 100) {
      console.log(`  ${c.name}: ${(winRate * 100).toFixed(1)}% win rate, ${c.total_votes} votes, ELO ${c.elo_rating}`);
    }
  }

  // Now fetch all matchups and analyze the outlier clubs
  console.log('\nFetching all matchups for deep session analysis...');
  const allMatchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  console.log(`Total matchups: ${allMatchups.length}`);

  // Count actual appearances per club from matchup data
  const actualAppearances = {};
  const actualWins = {};
  for (const m of allMatchups) {
    actualAppearances[m.club_a_id] = (actualAppearances[m.club_a_id] || 0) + 1;
    actualAppearances[m.club_b_id] = (actualAppearances[m.club_b_id] || 0) + 1;
    if (m.winner_id) {
      actualWins[m.winner_id] = (actualWins[m.winner_id] || 0) + 1;
    }
  }

  console.log('\nActual vote distribution from matchup data:');
  const sortedByAppearance = Object.entries(actualAppearances).sort((a, b) => b[1] - a[1]);
  for (const [clubId, count] of sortedByAppearance.slice(0, 15)) {
    const wins = actualWins[clubId] || 0;
    const winRate = (wins / count * 100).toFixed(1);
    console.log(`  ${(clubNames[clubId] || clubId).padEnd(40)} ${String(count).padStart(6)} appearances, ${String(wins).padStart(6)} wins (${winRate}%)`);
  }

  // For each outlier, analyze their sessions
  const outlierIds = new Set(outliers.map(c => c.id));

  // Group matchups by session
  const bySession = {};
  for (const m of allMatchups) {
    if (!bySession[m.session_id]) bySession[m.session_id] = [];
    bySession[m.session_id].push(m);
  }

  console.log(`\nTotal sessions: ${Object.keys(bySession).length}`);

  // For each outlier club, find sessions that disproportionately involve them
  for (const c of outliers) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Analyzing: ${c.name} (${c.total_votes} votes, ${c.wins} wins)`);
    console.log(`${'='.repeat(60)}`);

    const clubMatchups = allMatchups.filter(m => m.club_a_id === c.id || m.club_b_id === c.id);
    const clubSessions = {};
    for (const m of clubMatchups) {
      if (!clubSessions[m.session_id]) clubSessions[m.session_id] = [];
      clubSessions[m.session_id].push(m);
    }

    // For each session involving this club, calculate what % of the session involves this club
    const sessionStats = [];
    for (const [sessId, clubVotes] of Object.entries(clubSessions)) {
      const totalSessionVotes = bySession[sessId].length;
      const appearanceRate = clubVotes.length / totalSessionVotes;
      const clubWinsInSession = clubVotes.filter(v => v.winner_id === c.id).length;
      const winRate = clubWinsInSession / clubVotes.length;
      const times = clubVotes.map(v => new Date(v.created_at).getTime()).sort();
      const avgInterval = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;

      sessionStats.push({
        sessId,
        totalSessionVotes,
        clubVotes: clubVotes.length,
        clubWins: clubWinsInSession,
        appearanceRate,
        winRate,
        avgInterval,
        ips: [...new Set(clubVotes.map(v => v.ip_address).filter(Boolean))],
      });
    }

    // Find suspicious sessions: high appearance rate OR the club votes are much higher than random chance
    // With 72 clubs, random chance for a club to appear is about 2/72 = 2.78% per matchup
    // So in a session of N votes, expected appearances = N * 2/72
    const suspicious = sessionStats.filter(s => {
      const expected = s.totalSessionVotes * (2 / clubs.length);
      return (s.clubVotes > expected * 3 && s.clubVotes >= 3) || // 3x expected appearances
             (s.appearanceRate >= 0.50 && s.clubVotes >= 3); // appears in 50%+ of session
    }).sort((a, b) => b.clubVotes - a.clubVotes);

    console.log(`  Total sessions: ${Object.keys(clubSessions).length}`);
    console.log(`  Suspicious sessions (3x expected appearances or 50%+ rate): ${suspicious.length}`);

    let suspiciousVoteCount = 0;
    for (const s of suspicious) {
      suspiciousVoteCount += s.totalSessionVotes; // entire session is suspicious
    }
    console.log(`  Total votes in suspicious sessions: ${suspiciousVoteCount}`);

    // Show top suspicious sessions
    for (const s of suspicious.slice(0, 15)) {
      console.log(`    ${s.sessId}: ${s.totalSessionVotes} total votes, ${c.name} in ${s.clubVotes} (${(s.appearanceRate * 100).toFixed(0)}%), wins ${s.clubWins}/${s.clubVotes} (${(s.winRate * 100).toFixed(0)}%), avg ${s.avgInterval.toFixed(1)}s, IP: ${s.ips.join(',')}`);
    }
  }

  // BROADER analysis: find ALL sessions where ANY club appears at 50%+ rate with 3+ votes
  console.log(`\n${'='.repeat(60)}`);
  console.log('BROAD SCAN: All sessions with any club at 50%+ appearance rate');
  console.log(`${'='.repeat(60)}`);

  const allBotSessions = [];
  for (const [sessId, votes] of Object.entries(bySession)) {
    if (votes.length < 3) continue;

    const clubAppearances = {};
    const clubWinsInSess = {};
    for (const v of votes) {
      for (const cid of [v.club_a_id, v.club_b_id]) {
        clubAppearances[cid] = (clubAppearances[cid] || 0) + 1;
      }
      if (v.winner_id) {
        clubWinsInSess[v.winner_id] = (clubWinsInSess[v.winner_id] || 0) + 1;
      }
    }

    for (const [clubId, appearances] of Object.entries(clubAppearances)) {
      const rate = appearances / votes.length;
      const wins = clubWinsInSess[clubId] || 0;
      const winRate = wins / appearances;

      // 50%+ appearance rate (random would be ~2.8%)
      if (rate >= 0.50 && appearances >= 3) {
        const times = votes.map(v => new Date(v.created_at).getTime()).sort();
        const avgInt = times.length > 1 ? (times[times.length - 1] - times[0]) / (times.length - 1) / 1000 : 0;
        allBotSessions.push({
          sessId,
          clubId,
          clubName: clubNames[clubId] || clubId,
          totalVotes: votes.length,
          clubAppearances: appearances,
          clubWins: wins,
          appearanceRate: rate,
          winRate,
          avgInterval: avgInt,
          ips: [...new Set(votes.map(v => v.ip_address).filter(Boolean))],
        });
        break;
      }
    }
  }

  // Group by club
  const botByClub = {};
  for (const s of allBotSessions) {
    if (!botByClub[s.clubName]) botByClub[s.clubName] = { sessions: 0, totalVotes: 0, clubWins: 0 };
    botByClub[s.clubName].sessions++;
    botByClub[s.clubName].totalVotes += s.totalVotes;
    botByClub[s.clubName].clubWins += s.clubWins;
  }

  console.log(`\nTotal suspicious sessions: ${allBotSessions.length}`);
  console.log(`Total votes in suspicious sessions: ${allBotSessions.reduce((a, b) => a + b.totalVotes, 0)}`);
  console.log('\nBy targeted club:');
  const sortedBotClubs = Object.entries(botByClub).sort((a, b) => b[1].totalVotes - a[1].totalVotes);
  for (const [name, info] of sortedBotClubs) {
    console.log(`  ${name.padEnd(40)} ${info.sessions} sessions, ${info.totalVotes} bot votes, ${info.clubWins} club wins`);
  }

  // Output all bot session IDs
  console.log(`\n--- All bot session IDs (${allBotSessions.length}) ---`);
  for (const s of allBotSessions.sort((a, b) => b.totalVotes - a.totalVotes)) {
    console.log(`  '${s.sessId}', -- ${s.clubName} (${s.totalVotes} votes, ${s.clubAppearances} appearances, ${s.clubWins} wins, ${(s.winRate * 100).toFixed(0)}% win rate)`);
  }
}

main().catch(console.error);
