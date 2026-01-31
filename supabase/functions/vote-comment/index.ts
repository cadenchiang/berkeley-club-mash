import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// In-memory rate limit store (resets on cold start, but still effective)
const ipVotes: Map<string, { count: number; resetAt: number }> = new Map()

const RATE_LIMIT = 30 // votes per window
const WINDOW_MS = 60 * 60 * 1000 // 1 hour

function isRateLimited(ip: string): boolean {
  const now = Date.now()
  const record = ipVotes.get(ip)

  if (!record || now > record.resetAt) {
    ipVotes.set(ip, { count: 1, resetAt: now + WINDOW_MS })
    return false
  }

  if (record.count >= RATE_LIMIT) {
    return true
  }

  record.count++
  return false
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get client IP from headers
    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
               req.headers.get('x-real-ip') ||
               req.headers.get('cf-connecting-ip') ||
               'unknown'

    // Check rate limit
    if (isRateLimited(ip)) {
      return new Response(
        JSON.stringify({ success: false, error: 'rate_limit', message: 'Too many votes. Try again later.' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { p_comment_id, p_session_id, p_vote_type, p_fingerprint } = await req.json()

    // Validate inputs
    if (!p_comment_id || !p_session_id || !p_vote_type) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_params' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role for database access
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Log the vote attempt with IP for tracking
    await supabase.from('vote_logs').insert({
      ip_address: ip,
      comment_id: p_comment_id,
      session_id: p_session_id,
      fingerprint: p_fingerprint,
    }).catch(() => {}) // Ignore errors on logging

    // Call the database function
    const { data, error } = await supabase.rpc('vote_comment', {
      p_comment_id,
      p_session_id,
      p_vote_type,
      p_fingerprint,
    })

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: 'server_error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
