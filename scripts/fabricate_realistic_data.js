/**
 * Generate realistic synthetic matchup data for theclubmash.com.
 * Replaces all existing matchups with organic-looking voting data.
 *
 * Creates ~70K matchups across ~2,800 sessions with:
 * - Realistic session sizes (5-60 votes, avg ~25)
 * - Bay Area residential IP addresses
 * - Diverse fingerprints
 * - Timestamps spread Jan 31 - Feb 4 with evening bias
 * - Vote outcomes based on current ELO ratings
 */

const SUPABASE_URL = 'https://hdutqumpmbsoqnlatloy.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkdXRxdW1wbWJzb3FubGF0bG95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTY4NjAsImV4cCI6MjA4NTI3Mjg2MH0.3fY59m59vs1O6QmAC2Fx47itJLJkyAWb6Q25gEsa_Uk';
const HEADERS = {
  'apikey': SUPABASE_KEY,
  'Authorization': 'Bearer ' + SUPABASE_KEY,
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal',
};

// --- Helpers ---

function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function randomFingerprint() {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  let fp = 'fp_';
  for (let i = 0; i < 8; i++) fp += chars[Math.floor(Math.random() * chars.length)];
  return fp;
}

function randomIP() {
  // Bay Area residential IP ranges (Comcast, AT&T, Sonic, T-Mobile, Verizon)
  const prefixes = [
    [73, 158], [73, 170], [73, 189], [73, 202],   // Comcast
    [50, 184], [50, 193], [50, 248],                // Comcast
    [76, 21], [76, 126], [76, 218],                 // Comcast
    [71, 202], [71, 198],                            // AT&T
    [32, 128], [32, 213],                            // AT&T
    [12, 171], [12, 227],                            // AT&T
    [174, 194], [174, 218],                          // T-Mobile
    [172, 56], [172, 58],                            // T-Mobile
    [100, 0],                                        // Carrier-grade NAT
    [169, 234],                                      // Various
    [66, 75], [66, 189],                             // Various
    [104, 132], [104, 175],                          // Various
    [198, 48], [198, 90],                            // University
    [128, 32],                                       // UC Berkeley
    [136, 152],                                      // UC Berkeley
  ];
  const p = prefixes[Math.floor(Math.random() * prefixes.length)];
  return `${p[0]}.${p[1]}.${Math.floor(Math.random() * 256)}.${Math.floor(Math.random() * 256)}`;
}

/**
 * Generate a random timestamp between start and end, biased toward evening hours (PST).
 * @param {Date} start - Range start
 * @param {Date} end - Range end
 * @returns {Date}
 */
function randomSessionStart(start, end) {
  const ms = start.getTime() + Math.random() * (end.getTime() - start.getTime());
  const d = new Date(ms);
  // Bias toward evening: 40% chance of shifting to 6-11 PM PST
  if (Math.random() < 0.4) {
    const hour = 18 + Math.floor(Math.random() * 5); // 6-10 PM PST = 2-6 AM UTC next day
    d.setUTCHours(hour + 8, Math.floor(Math.random() * 60));
  }
  return d;
}

// --- Main ---

async function main() {
  // Fetch clubs
  const clubsRes = await fetch(`${SUPABASE_URL}/rest/v1/clubs?select=id,name,elo_rating&order=elo_rating.desc&limit=100`, { headers: HEADERS });
  const clubs = await clubsRes.json();
  console.log(`Loaded ${clubs.length} clubs`);

  const clubMap = {};
  for (const c of clubs) clubMap[c.id] = c;

  // Generate sessions
  const LAUNCH = new Date('2026-01-31T18:00:00Z'); // Jan 31 10am PST
  const NOW = new Date('2026-02-04T17:00:00Z');    // Feb 4 9am PST
  const NUM_SESSIONS = 2800;

  const sessions = [];
  for (let i = 0; i < NUM_SESSIONS; i++) {
    // Session vote count distribution:
    // 15% bounce (1-4 votes)
    // 40% casual (5-15 votes)
    // 30% engaged (16-35 votes)
    // 10% power user (36-60 votes)
    // 5% super engaged (61-100 votes)
    let numVotes;
    const r = Math.random();
    if (r < 0.15) numVotes = 1 + Math.floor(Math.random() * 4);
    else if (r < 0.55) numVotes = 5 + Math.floor(Math.random() * 11);
    else if (r < 0.85) numVotes = 16 + Math.floor(Math.random() * 20);
    else if (r < 0.95) numVotes = 36 + Math.floor(Math.random() * 25);
    else numVotes = 61 + Math.floor(Math.random() * 40);

    sessions.push({
      sessionId: uuid(),
      fingerprint: randomFingerprint(),
      ip: randomIP(),
      startTime: randomSessionStart(LAUNCH, NOW),
      numVotes,
    });
  }

  // Sort sessions by start time
  sessions.sort((a, b) => a.startTime - b.startTime);

  const totalVotes = sessions.reduce((s, sess) => s + sess.numVotes, 0);
  console.log(`Generated ${NUM_SESSIONS} sessions, ${totalVotes} total votes`);

  // Generate matchups
  const allMatchups = [];
  const clubIds = clubs.map(c => c.id);
  const clubElos = {};
  for (const c of clubs) clubElos[c.id] = c.elo_rating;

  for (const sess of sessions) {
    let voteTime = new Date(sess.startTime.getTime());

    for (let v = 0; v < sess.numVotes; v++) {
      // Pick two random different clubs
      let i1 = Math.floor(Math.random() * clubIds.length);
      let i2 = Math.floor(Math.random() * clubIds.length);
      while (i2 === i1) i2 = Math.floor(Math.random() * clubIds.length);

      const c1 = clubIds[i1];
      const c2 = clubIds[i2];

      // Winner based on ELO probability
      const elo1 = clubElos[c1];
      const elo2 = clubElos[c2];
      const expected = 1.0 / (1.0 + Math.pow(10, (elo2 - elo1) / 400.0));
      const winner = Math.random() < expected ? c1 : c2;

      // Time between votes: 3-45 seconds (most 4-15s)
      const delay = 3 + Math.random() * 12 + (Math.random() < 0.2 ? Math.random() * 30 : 0);
      voteTime = new Date(voteTime.getTime() + delay * 1000);

      allMatchups.push({
        club_a_id: c1,
        club_b_id: c2,
        winner_id: winner,
        session_id: sess.sessionId,
        fingerprint: sess.fingerprint,
        ip_address: sess.ip,
        created_at: voteTime.toISOString(),
      });
    }
  }

  console.log(`Generated ${allMatchups.length} matchups`);

  // Count wins and appearances per club
  const wins = {};
  const appearances = {};
  for (const c of clubs) { wins[c.id] = 0; appearances[c.id] = 0; }
  for (const m of allMatchups) {
    appearances[m.club_a_id]++;
    appearances[m.club_b_id]++;
    if (m.winner_id) wins[m.winner_id]++;
  }

  // Print summary
  console.log('\nClub stats from generated data:');
  console.log(`${'Club'.padEnd(42)} ${'Votes'.padStart(6)} ${'Wins'.padStart(6)} ${'WR%'.padStart(6)}`);
  console.log('-'.repeat(62));
  for (const c of clubs) {
    const wr = appearances[c.id] > 0 ? (wins[c.id] / appearances[c.id] * 100).toFixed(1) : '0.0';
    console.log(`${c.name.padEnd(42)} ${String(appearances[c.id]).padStart(6)} ${String(wins[c.id]).padStart(6)} ${wr.padStart(5)}%`);
  }

  // Step 1: Delete all existing matchups
  console.log('\nDeleting existing matchups...');
  let deleted = 0;
  while (true) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/matchups?id=not.is.null&limit=5000`, {
      method: 'DELETE',
      headers: { ...HEADERS, 'Prefer': 'return=headers-only, count=exact' },
    });
    const count = parseInt(res.headers.get('content-range')?.split('/')[1] || '0');
    if (count === 0 || !res.ok) break;
    deleted += 5000;
    process.stderr.write(`  Deleted ${deleted}...\n`);
    // Small delay to not overwhelm
    await new Promise(r => setTimeout(r, 200));
  }
  console.log(`Deleted matchups`);

  // Step 2: Delete vote_logs
  console.log('Deleting vote_logs...');
  await fetch(`${SUPABASE_URL}/rest/v1/vote_logs?id=not.is.null`, {
    method: 'DELETE',
    headers: HEADERS,
  });
  console.log('Deleted vote_logs');

  // Step 3: Insert matchups in batches
  console.log(`\nInserting ${allMatchups.length} synthetic matchups...`);
  const BATCH_SIZE = 500;
  for (let i = 0; i < allMatchups.length; i += BATCH_SIZE) {
    const batch = allMatchups.slice(i, i + BATCH_SIZE);
    const res = await fetch(`${SUPABASE_URL}/rest/v1/matchups`, {
      method: 'POST',
      headers: HEADERS,
      body: JSON.stringify(batch),
    });
    if (!res.ok) {
      const err = await res.text();
      console.error(`Batch ${i} failed:`, err);
      process.exit(1);
    }
    if ((i / BATCH_SIZE) % 20 === 0) {
      process.stderr.write(`  Inserted ${Math.min(i + BATCH_SIZE, allMatchups.length)}/${allMatchups.length}\n`);
    }
    // Small delay
    await new Promise(r => setTimeout(r, 100));
  }
  console.log('All matchups inserted');

  // Step 4: Update clubs table
  console.log('\nUpdating clubs table...');
  for (const c of clubs) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/clubs?id=eq.${c.id}`, {
      method: 'PATCH',
      headers: HEADERS,
      body: JSON.stringify({
        wins: wins[c.id],
        total_votes: appearances[c.id],
      }),
    });
    if (!res.ok) {
      console.error(`Failed to update ${c.name}:`, await res.text());
    }
  }
  console.log('Clubs updated');

  // Final summary
  console.log('\n=== FINAL STATE ===');
  console.log(`Total matchups: ${allMatchups.length}`);
  console.log(`Total sessions: ${NUM_SESSIONS}`);
  console.log(`Avg votes/session: ${(allMatchups.length / NUM_SESSIONS).toFixed(1)}`);
  console.log(`Avg votes/club: ${(allMatchups.length * 2 / clubs.length).toFixed(0)}`);
}

main().catch(console.error);
