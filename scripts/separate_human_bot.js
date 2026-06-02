/**
 * Separate likely-human votes from likely-bot votes by analyzing:
 * - Session size and timing
 * - Vote velocity
 * Then replay ELO using only "likely human" votes to see if
 * rankings differ meaningfully from the noise-diluted rankings.
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
  for (const c of clubs) {
    elos[c.id] = 1500;
    wins[c.id] = 0;
    totalVotes[c.id] = 0;
  }
  for (const m of matchups) {
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
  return { elos, wins, totalVotes };
}

async function main() {
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

  console.log('Fetching all matchups...');
  const allMatchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  console.log(`Total: ${allMatchups.length}\n`);

  // Group by session
  const bySession = {};
  for (const m of allMatchups) {
    if (!bySession[m.session_id]) bySession[m.session_id] = [];
    bySession[m.session_id].push(m);
  }

  // Classify sessions
  const rapidFireSessions = new Set(); // avg < 4s interval AND 10+ votes
  const largeRandomSessions = new Set(); // 50+ votes with avg < 15s
  const suspiciousFingerprints = {};

  for (const [sessId, votes] of Object.entries(bySession)) {
    if (votes.length < 2) continue;
    const times = votes.map(v => new Date(v.created_at).getTime()).sort();
    const avgInterval = (times[times.length - 1] - times[0]) / (times.length - 1) / 1000;

    if (avgInterval < 4 && votes.length >= 10) {
      rapidFireSessions.add(sessId);
    }
    if (votes.length >= 50 && avgInterval < 15) {
      largeRandomSessions.add(sessId);
    }

    // Track fingerprints with many sessions
    for (const v of votes) {
      if (v.fingerprint) {
        if (!suspiciousFingerprints[v.fingerprint]) suspiciousFingerprints[v.fingerprint] = new Set();
        suspiciousFingerprints[v.fingerprint].add(sessId);
      }
    }
  }

  // Check fingerprints that appear across many sessions (potential bot fingerprints)
  const multiFPSessions = new Set();
  for (const [fp, sessions] of Object.entries(suspiciousFingerprints)) {
    // Check total votes for this fingerprint
    let totalVotes = 0;
    for (const sessId of sessions) {
      totalVotes += bySession[sessId].length;
    }
    // A fingerprint with 200+ total votes across sessions might be a bot
    if (totalVotes >= 200 && sessions.size >= 5) {
      // Check average interval across all their sessions
      for (const sessId of sessions) {
        const votes = bySession[sessId];
        if (votes.length >= 5) {
          const times = votes.map(v => new Date(v.created_at).getTime()).sort();
          const avgInt = (times[times.length - 1] - times[0]) / (times.length - 1) / 1000;
          if (avgInt < 10) multiFPSessions.add(sessId);
        }
      }
    }
  }

  // Combine all bot sessions
  const allBotSessions = new Set([...rapidFireSessions, ...largeRandomSessions, ...multiFPSessions]);

  // Count votes in each category
  let rapidVotes = 0, largeVotes = 0, multiFPVotes = 0, allBotVotes = 0;
  for (const sessId of rapidFireSessions) rapidVotes += bySession[sessId].length;
  for (const sessId of largeRandomSessions) largeVotes += bySession[sessId].length;
  for (const sessId of multiFPSessions) multiFPVotes += bySession[sessId].length;
  for (const sessId of allBotSessions) allBotVotes += bySession[sessId].length;

  console.log('=== Bot classification ===');
  console.log(`Rapid-fire sessions (avg <4s, 10+ votes): ${rapidFireSessions.size} sessions, ${rapidVotes} votes`);
  console.log(`Large random sessions (50+ votes, avg <15s): ${largeRandomSessions.size} sessions, ${largeVotes} votes`);
  console.log(`Multi-session fingerprints (200+ votes, 5+ sessions): ${multiFPSessions.size} sessions, ${multiFPVotes} votes`);
  console.log(`Combined bot sessions: ${allBotSessions.size} sessions, ${allBotVotes} votes`);

  // Now split matchups
  const humanMatchups = allMatchups.filter(m => !allBotSessions.has(m.session_id));
  const botMatchups = allMatchups.filter(m => allBotSessions.has(m.session_id));
  console.log(`\nHuman matchups: ${humanMatchups.length} (${(humanMatchups.length/allMatchups.length*100).toFixed(1)}%)`);
  console.log(`Bot matchups: ${botMatchups.length} (${(botMatchups.length/allMatchups.length*100).toFixed(1)}%)`);

  // Single-vote sessions are ambiguous — analyze them separately
  const singleVoteSessions = Object.entries(bySession).filter(([_, v]) => v.length === 1);
  const multiVoteHumanSessions = Object.entries(bySession).filter(([id, v]) => v.length > 1 && !allBotSessions.has(id));
  console.log(`\nSingle-vote sessions: ${singleVoteSessions.length} (${(singleVoteSessions.length / Object.keys(bySession).length * 100).toFixed(1)}% of sessions)`);
  console.log(`Multi-vote human sessions: ${multiVoteHumanSessions.length}`);

  // Replay ELO three ways:
  // 1. All remaining matchups (current state)
  // 2. Only multi-vote human sessions (exclude single-vote AND bots)
  // 3. Exclude only the identified bots (keep single-vote)

  console.log('\n=== ELO COMPARISON ===');
  console.log('Replaying ELOs three ways...\n');

  const multiVoteHumanMatchups = allMatchups.filter(m => {
    const sess = bySession[m.session_id];
    return sess.length > 1 && !allBotSessions.has(m.session_id);
  });

  const eloAll = replayElo(allMatchups, clubs);
  const eloHuman = replayElo(humanMatchups, clubs);
  const eloMultiHuman = replayElo(multiVoteHumanMatchups, clubs);

  console.log(`All matchups: ${allMatchups.length}`);
  console.log(`Without bots: ${humanMatchups.length}`);
  console.log(`Multi-vote human only: ${multiVoteHumanMatchups.length}`);

  // Print side-by-side comparison sorted by multi-vote-human ELO
  const sorted = [...clubs].sort((a, b) => (eloMultiHuman.elos[b.id] || 1500) - (eloMultiHuman.elos[a.id] || 1500));

  console.log(`\n${'Club'.padEnd(40)} ${'All'.padStart(5)} ${'NoBots'.padStart(7)} ${'MultiH'.padStart(7)} ${'MH_WR'.padStart(6)} ${'MH_Votes'.padStart(8)}`);
  console.log('-'.repeat(76));
  for (const c of sorted) {
    if (eloMultiHuman.totalVotes[c.id] < 10) continue;
    const wr = eloMultiHuman.totalVotes[c.id] > 0 ? (eloMultiHuman.wins[c.id] / eloMultiHuman.totalVotes[c.id] * 100).toFixed(1) : '0.0';
    console.log(`${c.name.padEnd(40)} ${String(eloAll.elos[c.id]).padStart(5)} ${String(eloHuman.elos[c.id]).padStart(7)} ${String(eloMultiHuman.elos[c.id]).padStart(7)} ${(wr + '%').padStart(6)} ${String(eloMultiHuman.totalVotes[c.id]).padStart(8)}`);
  }

  // Show the ELO range for each method
  const allElos = Object.values(eloAll.elos).filter(e => e !== 1500 || true);
  const humanElos = Object.values(eloHuman.elos);
  const multiElos = Object.values(eloMultiHuman.elos).filter((_, i) => eloMultiHuman.totalVotes[clubs[i].id] >= 10);

  console.log(`\nELO ranges:`);
  console.log(`  All:        ${Math.min(...allElos)} - ${Math.max(...allElos)} (spread: ${Math.max(...allElos) - Math.min(...allElos)})`);
  console.log(`  No bots:    ${Math.min(...humanElos)} - ${Math.max(...humanElos)} (spread: ${Math.max(...humanElos) - Math.min(...humanElos)})`);
  console.log(`  Multi-human: ${Math.min(...multiElos)} - ${Math.max(...multiElos)} (spread: ${Math.max(...multiElos) - Math.min(...multiElos)})`);

  // Output the bot session IDs for removal
  console.log(`\n--- Bot sessions to remove (${allBotSessions.size}) ---`);
  const botList = [...allBotSessions].sort();
  for (const id of botList) {
    console.log(`  '${id}',  -- ${bySession[id].length} votes`);
  }
}

main().catch(console.error);
