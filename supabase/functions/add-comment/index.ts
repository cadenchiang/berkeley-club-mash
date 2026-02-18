import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * In-memory IP rate limit store for comment submissions.
 * Enforces a 10-second cooldown per IP and a max of 20 comments per hour.
 * Resets on cold start but still effective against sustained attacks.
 */
const ipComments: Map<string, { lastAt: number; count: number; resetAt: number }> = new Map()

const COOLDOWN_MS = 10_000        // 10 seconds between comments per IP
const HOURLY_LIMIT = 20           // max comments per hour per IP
const WINDOW_MS = 60 * 60 * 1000  // 1 hour

function checkRateLimit(ip: string): { allowed: boolean; error?: string } {
  const now = Date.now()
  const record = ipComments.get(ip)

  if (!record || now > record.resetAt) {
    ipComments.set(ip, { lastAt: now, count: 1, resetAt: now + WINDOW_MS })
    return { allowed: true }
  }

  // Cooldown check (10 seconds between comments)
  if (now - record.lastAt < COOLDOWN_MS) {
    return { allowed: false, error: 'Please wait a few seconds before posting again.' }
  }

  // Hourly limit check
  if (record.count >= HOURLY_LIMIT) {
    return { allowed: false, error: 'Too many comments. Please try again later.' }
  }

  record.lastAt = now
  record.count++
  return { allowed: true }
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

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')

    if (!supabaseUrl || !supabaseKey) {
      console.error('Missing env vars:', { url: !!supabaseUrl, key: !!supabaseKey })
      return new Response(
        JSON.stringify({ success: false, error: 'config_error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

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

    // IP-based rate limit
    const rateCheck = checkRateLimit(ip)
    if (!rateCheck.allowed) {
      return new Response(
        JSON.stringify({ success: false, error: 'rate_limit', message: rateCheck.error }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { p_club_id, p_content, p_session_id, p_parent_id, turnstile_token } = await req.json()

    if (!p_club_id || !p_content || !p_session_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_params', message: 'Missing required fields.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate Cloudflare Turnstile token
    const turnstileSecret = Deno.env.get('TURNSTILE_SECRET_KEY')
    if (turnstileSecret && turnstile_token) {
      const tsRes = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `secret=${encodeURIComponent(turnstileSecret)}&response=${encodeURIComponent(turnstile_token)}&remoteip=${encodeURIComponent(ip)}`,
      })
      const tsData = await tsRes.json()
      if (!tsData.success) {
        return new Response(
          JSON.stringify({ success: false, error: 'captcha_failed', message: 'Verification failed.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    } else if (turnstileSecret && !turnstile_token) {
      return new Response(
        JSON.stringify({ success: false, error: 'captcha_required', message: 'Verification required.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Call the database function
    const { data, error } = await supabase.rpc('add_comment', {
      p_club_id,
      p_content: p_content.trim(),
      p_session_id,
      p_parent_id: p_parent_id || null,
    })

    if (error) {
      console.error('add_comment RPC error:', error)
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify(data),
      { status: data.success ? 200 : 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('add-comment function error:', err)
    return new Response(
      JSON.stringify({ success: false, error: 'server_error', details: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
