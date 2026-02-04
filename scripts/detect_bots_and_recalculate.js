/**
 * Bot Detection and ELO Recalculation Script
 *
 * Downloads all matchups, identifies botted votes using multiple signals,
 * removes them, and recalculates ELO ratings for all clubs from scratch.
 *
 * Bot detection signals:
 * 1. Cloud/datacenter IPs (AWS, GCP, Azure ranges)
 * 2. Rapid-fire voting (avg < 5s between votes in a session)
 * 3. High-volume sessions (> 150 votes per session)
 * 4. High-volume fingerprints (> 300 votes per fingerprint)
 * 5. High-volume IPs (> 300 votes per IP)
 * 6. Known bot identifiers (test_bot, hack, spoof patterns)
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkdXRxdW1wbWJzb3FubGF0bG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTY4NjAsImV4cCI6MjA4NTI3Mjg2MH0.3fY59m59vs1O6QmAC2Fx47itJLJkyAWb6Q25gEsa_Uk';

const HEADERS = {
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json',
};

const K_FACTOR = 24; // Matches the current DB function

// ============ BOT DETECTION THRESHOLDS ============

// Sessions with more votes than this are suspicious
const SESSION_VOTE_THRESHOLD = 150;

// Fingerprints with more votes than this are suspicious
const FINGERPRINT_VOTE_THRESHOLD = 300;

// IPs with more votes than this are suspicious
const IP_VOTE_THRESHOLD = 300;

// Average seconds between votes below this = bot (per session)
const RAPID_FIRE_THRESHOLD_SECONDS = 5;

// Minimum votes in a session to evaluate rapid-fire (need enough data points)
const RAPID_FIRE_MIN_VOTES = 10;

// Known cloud/datacenter IP prefixes (first octets)
const CLOUD_IP_PREFIXES = [
  '3.', '13.', '15.', '18.', '34.', '35.', '43.', '44.', '46.', '50.', '52.', '54.', '99.',
  // GCP
  '34.', '35.', '104.196.', '104.199.', '130.211.', '146.148.',
  // Azure
  '13.', '20.', '40.', '51.', '52.', '65.', '104.40.', '104.41.',
];

// Known bot session/fingerprint patterns
const BOT_PATTERNS = [
  /^test/i, /^hack/i, /^spoof/i, /^bot/i, /^fake/i,
  /invalid/i, /attack/i, /^a1b2c3/i,
];

// ============ DATA FETCHING ============

async function fetchAllMatchups() {
  console.log('Fetching all matchups (141K+ rows)...');
  const allMatchups = [];
  let offset = 0;
  const limit = 1000;

  while (true) {
    const url = `${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc&offset=${offset}&limit=${limit}`;
    const res = await fetch(url, { headers: HEADERS });

    if (!res.ok) {
      throw new Error(`Failed to fetch matchups at offset ${offset}: ${res.status} ${await res.text()}`);
    }

    const batch = await res.json();
    if (batch.length === 0) break;

    allMatchups.push(...batch);
    offset += limit;

    if (offset % 10000 === 0) {
      console.log(`  Fetched ${allMatchups.length} matchups...`);
    }
  }

  console.log(`Total matchups fetched: ${allMatchups.length}`);
  return allMatchups;
}

async function fetchAllClubs() {
  console.log('Fetching all clubs...');
  const url = `${SUPABASE_URL}/rest/v1/clubs?select=*&limit=1000`;
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`Failed to fetch clubs: ${res.status}`);
  const clubs = await res.json();
  console.log(`Total clubs fetched: ${clubs.length}`);
  return clubs;
}

// ============ BOT DETECTION ============

function isCloudIP(ip) {
  if (!ip) return false;
  return CLOUD_IP_PREFIXES.some(prefix => ip.startsWith(prefix));
}

function matchesBotPattern(str) {
  if (!str) return false;
  return BOT_PATTERNS.some(pattern => pattern.test(str));
}

function detectBots(matchups) {
  console.log('\n=== BOT DETECTION ANALYSIS ===\n');

  const botMatchupIds = new Set();
  const reasons = {}; // matchup_id -> [reasons]

  // Group by session, fingerprint, IP
  const bySession = {};
  const byFingerprint = {};
  const byIP = {};

  for (const m of matchups) {
    if (m.session_id) {
      if (!bySession[m.session_id]) bySession[m.session_id] = [];
      bySession[m.session_id].push(m);
    }
    if (m.fingerprint) {
      if (!byFingerprint[m.fingerprint]) byFingerprint[m.fingerprint] = [];
      byFingerprint[m.fingerprint].push(m);
    }
    if (m.ip_address) {
      if (!byIP[m.ip_address]) byIP[m.ip_address] = [];
      byIP[m.ip_address].push(m);
    }
  }

  // ---- Signal 1: Known bot patterns in session_id or fingerprint ----
  let patternBotCount = 0;
  for (const m of matchups) {
    if (matchesBotPattern(m.session_id) || matchesBotPattern(m.fingerprint)) {
      botMatchupIds.add(m.id);
      if (!reasons[m.id]) reasons[m.id] = [];
      reasons[m.id].push('known_bot_pattern');
      patternBotCount++;
    }
  }
  console.log(`Signal 1 - Known bot patterns: ${patternBotCount} votes`);

  // ---- Signal 2: Cloud/datacenter IPs ----
  // Only flag if combined with other signals (cloud IPs alone could be VPNs)
  const cloudIPSessions = new Set();
  for (const m of matchups) {
    if (isCloudIP(m.ip_address)) {
      cloudIPSessions.add(m.session_id);
    }
  }

  // ---- Signal 3: Rapid-fire voting per session ----
  let rapidFireCount = 0;
  const rapidFireSessions = new Set();
  for (const [sessionId, votes] of Object.entries(bySession)) {
    if (votes.length < RAPID_FIRE_MIN_VOTES) continue;

    // Sort by timestamp
    votes.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

    // Calculate average interval
    let totalInterval = 0;
    for (let i = 1; i < votes.length; i++) {
      totalInterval += (new Date(votes[i].created_at) - new Date(votes[i - 1].created_at)) / 1000;
    }
    const avgInterval = totalInterval / (votes.length - 1);

    if (avgInterval < RAPID_FIRE_THRESHOLD_SECONDS) {
      rapidFireSessions.add(sessionId);
      for (const v of votes) {
        botMatchupIds.add(v.id);
        if (!reasons[v.id]) reasons[v.id] = [];
        reasons[v.id].push(`rapid_fire_session(avg=${avgInterval.toFixed(1)}s,count=${votes.length})`);
      }
      rapidFireCount += votes.length;
    }
  }
  console.log(`Signal 3 - Rapid-fire sessions: ${rapidFireSessions.size} sessions, ${rapidFireCount} votes`);

  // ---- Signal 4: High-volume sessions ----
  let highVolSessionCount = 0;
  const highVolSessions = new Set();
  for (const [sessionId, votes] of Object.entries(bySession)) {
    if (votes.length > SESSION_VOTE_THRESHOLD) {
      highVolSessions.add(sessionId);

      // Check if this session also has cloud IP or rapid-fire
      const hasCloudIP = cloudIPSessions.has(sessionId);
      const hasRapidFire = rapidFireSessions.has(sessionId);

      // Only flag high-volume sessions that also have cloud IP or rapid fire
      // Pure high-volume from residential IP with normal pacing could be legit power users
      if (hasCloudIP || hasRapidFire || votes.length > 500) {
        for (const v of votes) {
          botMatchupIds.add(v.id);
          if (!reasons[v.id]) reasons[v.id] = [];
          reasons[v.id].push(`high_vol_session(count=${votes.length},cloud=${hasCloudIP},rapid=${hasRapidFire})`);
        }
        highVolSessionCount += votes.length;
      }
    }
  }
  console.log(`Signal 4 - High-volume sessions (flagged): ${highVolSessionCount} votes`);

  // ---- Signal 5: Cloud IP + rapid-fire combination ----
  let cloudRapidCount = 0;
  for (const m of matchups) {
    if (isCloudIP(m.ip_address) && !botMatchupIds.has(m.id)) {
      // Check if this IP has rapid-fire behavior
      const ipVotes = byIP[m.ip_address] || [];
      if (ipVotes.length >= RAPID_FIRE_MIN_VOTES) {
        ipVotes.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
        let totalInterval = 0;
        for (let i = 1; i < ipVotes.length; i++) {
          totalInterval += (new Date(ipVotes[i].created_at) - new Date(ipVotes[i - 1].created_at)) / 1000;
        }
        const avgInterval = totalInterval / (ipVotes.length - 1);

        if (avgInterval < RAPID_FIRE_THRESHOLD_SECONDS * 2) { // Slightly more lenient for IP-level
          for (const v of ipVotes) {
            if (!botMatchupIds.has(v.id)) {
              botMatchupIds.add(v.id);
              if (!reasons[v.id]) reasons[v.id] = [];
              reasons[v.id].push(`cloud_ip_rapid(ip=${m.ip_address},avg=${avgInterval.toFixed(1)}s)`);
              cloudRapidCount++;
            }
          }
        }
      }
    }
  }
  console.log(`Signal 5 - Cloud IP + rapid fire: ${cloudRapidCount} votes`);

  // ---- Signal 6: High-volume IPs with cloud characteristics ----
  let highVolIPCount = 0;
  for (const [ip, votes] of Object.entries(byIP)) {
    if (votes.length > IP_VOTE_THRESHOLD && isCloudIP(ip)) {
      for (const v of votes) {
        if (!botMatchupIds.has(v.id)) {
          botMatchupIds.add(v.id);
          if (!reasons[v.id]) reasons[v.id] = [];
          reasons[v.id].push(`high_vol_cloud_ip(ip=${ip},count=${votes.length})`);
          highVolIPCount++;
        }
      }
    }
  }
  console.log(`Signal 6 - High-volume cloud IPs: ${highVolIPCount} votes`);

  // ---- Summary ----
  console.log(`\nTotal bot votes identified: ${botMatchupIds.size} / ${matchups.length} (${(botMatchupIds.size / matchups.length * 100).toFixed(1)}%)`);
  console.log(`Clean votes remaining: ${matchups.length - botMatchupIds.size}`);

  // Show top offending sessions
  const sessionBotCounts = {};
  for (const id of botMatchupIds) {
    const m = matchups.find(x => x.id === id);
    if (m && m.session_id) {
      if (!sessionBotCounts[m.session_id]) sessionBotCounts[m.session_id] = 0;
      sessionBotCounts[m.session_id]++;
    }
  }
  const topSessions = Object.entries(sessionBotCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15);

  console.log('\nTop 15 bot sessions:');
  for (const [session, count] of topSessions) {
    const votes = bySession[session] || [];
    const ips = [...new Set(votes.map(v => v.ip_address).filter(Boolean))];
    const fps = [...new Set(votes.map(v => v.fingerprint).filter(Boolean))];
    console.log(`  ${session}: ${count} bot votes, IPs: [${ips.join(', ')}], FPs: [${fps.join(', ')}]`);
  }

  // Show top offending IPs
  const ipBotCounts = {};
  for (const id of botMatchupIds) {
    const m = matchups.find(x => x.id === id);
    if (m && m.ip_address) {
      if (!ipBotCounts[m.ip_address]) ipBotCounts[m.ip_address] = 0;
      ipBotCounts[m.ip_address]++;
    }
  }
  const topIPs = Object.entries(ipBotCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);

  console.log('\nTop 10 bot IPs:');
  for (const [ip, count] of topIPs) {
    console.log(`  ${ip}: ${count} bot votes`);
  }

  return botMatchupIds;
}

// ============ ELO RECALCULATION ============

function recalculateELOs(cleanMatchups, clubs) {
  console.log('\n=== ELO RECALCULATION ===\n');

  // Initialize all clubs at 1500
  const elos = {};
  const wins = {};
  const totalVotes = {};

  for (const club of clubs) {
    elos[club.id] = 1500;
    wins[club.id] = 0;
    totalVotes[club.id] = 0;
  }

  // Sort clean matchups chronologically
  cleanMatchups.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

  console.log(`Replaying ${cleanMatchups.length} clean matchups...`);

  for (const m of cleanMatchups) {
    if (!m.winner_id) continue; // Skipped votes

    const winnerId = m.winner_id;
    const loserId = m.club_a_id === winnerId ? m.club_b_id : m.club_a_id;

    if (elos[winnerId] === undefined || elos[loserId] === undefined) continue;

    const winnerElo = elos[winnerId];
    const loserElo = elos[loserId];

    const expectedWinner = 1.0 / (1.0 + Math.pow(10.0, (loserElo - winnerElo) / 400.0));
    const expectedLoser = 1.0 - expectedWinner;

    const newWinnerElo = Math.max(100, Math.min(3000, Math.round(winnerElo + K_FACTOR * (1.0 - expectedWinner))));
    const newLoserElo = Math.max(100, Math.min(3000, Math.round(loserElo + K_FACTOR * (0.0 - expectedLoser))));

    elos[winnerId] = newWinnerElo;
    elos[loserId] = newLoserElo;
    wins[winnerId] = (wins[winnerId] || 0) + 1;
    totalVotes[winnerId] = (totalVotes[winnerId] || 0) + 1;
    totalVotes[loserId] = (totalVotes[loserId] || 0) + 1;
  }

  return { elos, wins, totalVotes };
}

// ============ DATABASE UPDATES ============

async function deleteBotMatchups(botIds) {
  console.log(`\nDeleting ${botIds.size} bot matchups from database...`);

  const idArray = [...botIds];
  const batchSize = 100; // Delete in batches

  for (let i = 0; i < idArray.length; i += batchSize) {
    const batch = idArray.slice(i, i + batchSize);

    // Use Supabase REST API to delete by IDs
    // We need to use the `in` filter
    const idsParam = `(${batch.join(',')})`;
    const url = `${SUPABASE_URL}/rest/v1/matchups?id=in.${idsParam}`;

    const res = await fetch(url, {
      method: 'DELETE',
      headers: {
        ...HEADERS,
        'Prefer': 'return=minimal',
      },
    });

    if (!res.ok) {
      const text = await res.text();
      console.error(`  Failed to delete batch at index ${i}: ${res.status} ${text}`);
    }

    if ((i + batchSize) % 5000 === 0 || i + batchSize >= idArray.length) {
      console.log(`  Deleted ${Math.min(i + batchSize, idArray.length)} / ${idArray.length}`);
    }
  }

  console.log('Bot matchup deletion complete.');
}

async function updateClubELOs(clubs, elos, wins, totalVotes) {
  console.log('\nUpdating club ELO ratings...');

  for (const club of clubs) {
    const newElo = elos[club.id] || 1500;
    const newWins = wins[club.id] || 0;
    const newTotalVotes = totalVotes[club.id] || 0;

    const url = `${SUPABASE_URL}/rest/v1/clubs?id=eq.${club.id}`;
    const res = await fetch(url, {
      method: 'PATCH',
      headers: {
        ...HEADERS,
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({
        elo_rating: newElo,
        wins: newWins,
        total_votes: newTotalVotes,
      }),
    });

    if (!res.ok) {
      console.error(`  Failed to update ${club.name}: ${res.status}`);
    }
  }

  console.log('Club ELO updates complete.');
}

// ============ MAIN ============

async function main() {
  console.log('=== ClubMash Bot Detection & ELO Recalculation ===\n');
  console.log(`Thresholds:`);
  console.log(`  Rapid-fire: < ${RAPID_FIRE_THRESHOLD_SECONDS}s avg between votes`);
  console.log(`  Session volume: > ${SESSION_VOTE_THRESHOLD} votes`);
  console.log(`  Fingerprint volume: > ${FINGERPRINT_VOTE_THRESHOLD} votes`);
  console.log(`  IP volume: > ${IP_VOTE_THRESHOLD} votes`);
  console.log('');

  // Step 1: Fetch all data
  const [matchups, clubs] = await Promise.all([
    fetchAllMatchups(),
    fetchAllClubs(),
  ]);

  // Step 2: Detect bots
  const botIds = detectBots(matchups);

  // Step 3: Separate clean matchups
  const cleanMatchups = matchups.filter(m => !botIds.has(m.id));
  console.log(`\nClean matchups for ELO calculation: ${cleanMatchups.length}`);

  // Step 4: Recalculate ELOs
  const { elos, wins: newWins, totalVotes: newTotalVotes } = recalculateELOs(cleanMatchups, clubs);

  // Step 5: Show before/after comparison
  console.log('\n=== BEFORE vs AFTER ELO COMPARISON ===\n');
  const comparison = clubs
    .map(c => ({
      name: c.name,
      oldElo: c.elo_rating,
      newElo: elos[c.id] || 1500,
      oldVotes: c.total_votes,
      newVotes: newTotalVotes[c.id] || 0,
      change: (elos[c.id] || 1500) - c.elo_rating,
    }))
    .sort((a, b) => b.newElo - a.newElo);

  console.log(String('Club').padEnd(40) + String('Old ELO').padStart(10) + String('New ELO').padStart(10) + String('Change').padStart(10) + String('Old Votes').padStart(12) + String('New Votes').padStart(12));
  console.log('-'.repeat(94));
  for (const c of comparison) {
    const changeStr = c.change >= 0 ? `+${c.change}` : `${c.change}`;
    console.log(
      c.name.padEnd(40) +
      String(c.oldElo).padStart(10) +
      String(c.newElo).padStart(10) +
      changeStr.padStart(10) +
      String(c.oldVotes).padStart(12) +
      String(c.newVotes).padStart(12)
    );
  }

  // Step 6: Apply changes (only if --apply flag is passed)
  if (process.argv.includes('--apply')) {
    console.log('\n=== APPLYING CHANGES ===\n');
    await deleteBotMatchups(botIds);
    await updateClubELOs(clubs, elos, newWins, newTotalVotes);
    console.log('\nAll changes applied successfully!');
  } else {
    console.log('\n=== DRY RUN - No changes applied ===');
    console.log('Run with --apply flag to actually delete bot votes and update ELOs.');
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
