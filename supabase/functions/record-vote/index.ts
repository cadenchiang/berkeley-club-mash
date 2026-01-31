import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// In-memory rate limit store
const ipVotes: Map<string, { count: number; resetAt: number }> = new Map()

const RATE_LIMIT = 200 // votes per hour before auto-ban
const WINDOW_MS = 60 * 60 * 1000 // 1 hour

function checkRateLimit(ip: string): { allowed: boolean; remaining: number } {
  const now = Date.now()
  const record = ipVotes.get(ip)

  if (!record || now > record.resetAt) {
    ipVotes.set(ip, { count: 1, resetAt: now + WINDOW_MS })
    return { allowed: true, remaining: RATE_LIMIT - 1 }
  }

  if (record.count >= RATE_LIMIT) {
    return { allowed: false, remaining: 0 }
  }

  record.count++
  return { allowed: true, remaining: RATE_LIMIT - record.count }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
               req.headers.get('x-real-ip') ||
               req.headers.get('cf-connecting-ip') ||
               'unknown'

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Check if IP is banned
    const { data: bannedIp } = await supabase
      .from('banned_ips')
      .select('ip_address')
      .eq('ip_address', ip)
      .single()

    if (bannedIp) {
      return new Response(
        JSON.stringify({ success: false, error: 'banned', message: 'Access denied.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const rateCheck = checkRateLimit(ip)
    if (!rateCheck.allowed) {
      // Auto-ban IP that hits rate limit
      try {
        await supabase.from('banned_ips').upsert({
          ip_address: ip,
          reason: 'Auto-banned: exceeded rate limit',
        }, { onConflict: 'ip_address' })
      } catch {}

      return new Response(
        JSON.stringify({ success: false, error: 'rate_limit', message: 'Too many votes. Try again later.' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { p_club_a_id, p_club_b_id, p_winner_id, p_session_id, p_fingerprint } = await req.json()

    if (!p_club_a_id || !p_club_b_id || !p_session_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_params' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log vote with IP (ignore errors)
    try {
      await supabase.from('vote_logs').insert({
        ip_address: ip,
        session_id: p_session_id,
        fingerprint: p_fingerprint,
      })
    } catch {}

    const { data, error } = await supabase.rpc('record_vote', {
      p_club_a_id,
      p_club_b_id,
      p_winner_id,
      p_session_id,
      p_fingerprint,
      p_edge_secret: '3eQp1PxTiWdLH6E1qZqgP0NHlE7atSI9',
    })

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ ...data, remaining_votes: rateCheck.remaining }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: 'server_error', details: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
