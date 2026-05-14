// Edge Function: generate-dashboard-magic-link
//
// Auth: requires the caller's JWT in Authorization header (auto-attached
// by supabase.functions.invoke from the iOS app). Validates the user,
// then uses the service-role key to generate a magic-link URL that signs
// them into the web dashboard via SFSafariViewController.
//
// Env vars (auto-injected by Supabase Edge runtime):
//   SUPABASE_URL
//   SUPABASE_ANON_KEY
//   SUPABASE_SERVICE_ROLE_KEY
//
// Custom env var (set via `supabase secrets set DASHBOARD_URL=...`):
//   DASHBOARD_URL — e.g. https://ontrack-dashboard.netlify.app
//
// Deploy:
//   supabase functions deploy generate-dashboard-magic-link

import { createClient } from 'npm:@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const dashboardUrl = Deno.env.get('DASHBOARD_URL')
  if (!supabaseUrl || !anonKey || !serviceRole) {
    return new Response(JSON.stringify({ error: 'Missing Supabase env vars' }), {
      status: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }
  if (!dashboardUrl) {
    return new Response(
      JSON.stringify({ error: 'DASHBOARD_URL secret not set. Run `supabase secrets set DASHBOARD_URL=https://<site>.netlify.app`' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    )
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization' }), {
      status: 401,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  // Validate caller's JWT using anon client w/ their auth header
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user?.email) {
    return new Response(JSON.stringify({ error: 'Invalid JWT or missing email' }), {
      status: 401,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  // Premium-only
  const { data: profile } = await userClient
    .from('profiles')
    .select('is_premium')
    .eq('id', user.id)
    .maybeSingle()
  if (!profile?.is_premium) {
    return new Response(JSON.stringify({ error: 'Premium required' }), {
      status: 403,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }

  // Mint magic-link via service-role
  const admin = createClient(supabaseUrl, serviceRole, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { data, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: user.email,
    options: {
      redirectTo: `${dashboardUrl}/dashboard/auth/callback`,
    },
  })
  if (linkError || !data?.properties?.action_link) {
    return new Response(
      JSON.stringify({ error: linkError?.message ?? 'Failed to generate link' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    )
  }

  return new Response(
    JSON.stringify({ url: data.properties.action_link }),
    { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
  )
})
