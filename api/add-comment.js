/**
 * Vercel serverless function to proxy comment submissions to Supabase Edge Function.
 * Forwards IP headers so the edge function can enforce per-IP rate limiting and Turnstile verification.
 */
export default async function handler(req, res) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const supabaseUrl = process.env.VITE_SUPABASE_URL;
    const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseAnonKey) {
      console.error('Missing Supabase environment variables');
      return res.status(500).json({ success: false, error: 'Server configuration error' });
    }

    // Forward request to Supabase Edge Function with auth and IP headers
    const response = await fetch(`${supabaseUrl}/functions/v1/add-comment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseAnonKey}`,
        'x-forwarded-for': req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown',
        'x-real-ip': req.headers['x-real-ip'] || '',
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.json();

    res.setHeader('Access-Control-Allow-Origin', '*');
    return res.status(response.status).json(data);
  } catch (error) {
    console.error('Add comment proxy error:', error);
    return res.status(500).json({ success: false, error: 'Proxy error', details: error.message });
  }
}
