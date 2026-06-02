/**
 * Find ALL targeted bot sessions across ALL clubs (not just Blockchain)
 *
 * A "targeted bot" session is one where:
 * - A single club appears in an unusually high percentage of the session's matchups
 * - That club wins most/all of its matchups in the session
 * - This indicates someone specifically botting FOR that club
 *
 * Also catches:
 * - Known bot IPs (107.21.89.25 and others identified in Blockchain analysis)
 * - Sessions where every vote involves the same club
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY;
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
    if (offset % 10000 === 0) console.log(`  Fetched ${all.length}...`);
  }
  return all;
}

async function main() {
  console.log('Fetching all remaining matchups...');
  const matchups = await fetchAll(`${SUPABASE_URL}/rest/v1/matchups?select=*&order=created_at.asc`);
  console.log(`Total remaining matchups: ${matchups.length}`);

  // Fetch clubs for name lookup
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name&limit=1000`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  const clubNames = {};
  for (const c of clubs) clubNames[c.id] = c.name;

  // Group by session
  const bySession = {};
  for (const m of matchups) {
    if (!bySession[m.session_id]) bySession[m.session_id] = [];
    bySession[m.session_id].push(m);
  }

  console.log(`Total sessions: ${Object.keys(bySession).length}`);

  const targetedBotIds = new Set();
  const botSessionDetails = [];

  for (const [sessId, votes] of Object.entries(bySession)) {
    if (votes.length < 3) continue; // Need at least 3 votes to detect pattern

    // Count how often each club appears and wins
    const clubAppearances = {};
    const clubWins = {};

    for (const v of votes) {
      for (const clubId of [v.club_a_id, v.club_b_id]) {
        clubAppearances[clubId] = (clubAppearances[clubId] || 0) + 1;
      }
      if (v.winner_id) {
        clubWins[v.winner_id] = (clubWins[v.winner_id] || 0) + 1;
      }
    }

    // Check for targeted botting: a club appears in 70%+ of matchups AND wins 85%+ of its matchups
    for (const [clubId, appearances] of Object.entries(clubAppearances)) {
      const appearanceRate = appearances / votes.length;
      const wins = clubWins[clubId] || 0;
      const winRate = wins / appearances;

      // Targeted bot: high appearance rate + high win rate + enough data
      if (appearanceRate >= 0.70 && winRate >= 0.85 && appearances >= 3) {
        // This is a targeted bot session
        for (const v of votes) {
          targetedBotIds.add(v.id);
        }
        botSessionDetails.push({
          sessId,
          clubId,
          clubName: clubNames[clubId] || clubId,
          totalVotes: votes.length,
          clubAppearances: appearances,
          clubWins: wins,
          appearanceRate,
          winRate,
          ips: [...new Set(votes.map(v => v.ip_address).filter(Boolean))],
          fps: [...new Set(votes.map(v => v.fingerprint).filter(Boolean))],
        });
        break; // Only count session once
      }
    }
  }

  // Also flag any votes from known bot IPs from the Blockchain analysis
  const knownBotIPs = ['107.21.89.25'];
  let knownIPCount = 0;
  for (const m of matchups) {
    if (m.ip_address && knownBotIPs.includes(m.ip_address) && !targetedBotIds.has(m.id)) {
      targetedBotIds.add(m.id);
      knownIPCount++;
    }
  }

  console.log(`\n=== TARGETED BOT DETECTION RESULTS ===`);
  console.log(`Targeted bot sessions: ${botSessionDetails.length}`);
  console.log(`Targeted bot matchups: ${targetedBotIds.size}`);
  console.log(`Known bot IP matchups (additional): ${knownIPCount}`);

  // Group by targeted club
  const byClub = {};
  for (const d of botSessionDetails) {
    if (!byClub[d.clubName]) byClub[d.clubName] = { sessions: 0, totalVotes: 0 };
    byClub[d.clubName].sessions++;
    byClub[d.clubName].totalVotes += d.totalVotes;
  }

  console.log('\nBotting by targeted club:');
  const sorted = Object.entries(byClub).sort((a, b) => b[1].totalVotes - a[1].totalVotes);
  for (const [name, info] of sorted) {
    console.log(`  ${name}: ${info.sessions} sessions, ${info.totalVotes} bot votes`);
  }

  console.log('\nTop 20 targeted bot sessions:');
  botSessionDetails.sort((a, b) => b.totalVotes - a.totalVotes);
  for (const d of botSessionDetails.slice(0, 20)) {
    console.log(`  ${d.sessId}: ${d.clubName} | ${d.totalVotes} votes (${d.clubAppearances} appearances, ${d.clubWins} wins) | appear ${(d.appearanceRate * 100).toFixed(0)}% win ${(d.winRate * 100).toFixed(0)}% | IP: ${d.ips.join(',')} | FP: ${d.fps.join(',')}`);
  }

  // Output the session IDs for use in SQL migration
  const botSessionIds = [...new Set(botSessionDetails.map(d => d.sessId))];
  console.log(`\n--- Bot session IDs for SQL migration (${botSessionIds.length} sessions) ---`);
  console.log(botSessionIds.map(id => `'${id}'`).join(',\n'));

  // Also output individual bot matchup IDs count
  console.log(`\nTotal bot matchup IDs to delete: ${targetedBotIds.size}`);
  console.log(`Clean matchups after this cleanup: ${matchups.length - targetedBotIds.size}`);
}

main().catch(console.error);
