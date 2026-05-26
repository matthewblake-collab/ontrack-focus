// Edge Function: push-dispatcher
//
// Called by pg_net DB webhooks (see migrations) on 7 tables. Resolves the
// recipient(s), signs an APNs ES256 JWT, and POSTs to PRODUCTION APNs.
//
// Auto-injected env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Custom secrets (supabase secrets set ...): APNS_PRIVATE_KEY (.p8 contents),
//   APNS_KEY_ID, APNS_TEAM_ID
//
// AuthZ: caller must present a service_role JWT (the trigger sends it). We
// reject any other valid project JWT (e.g. anon) so clients cannot forge
// webhook bodies and spam arbitrary device tokens.
//
// Deploy: supabase functions deploy push-dispatcher

import { createClient } from 'npm:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')!
const APNS_HOST = 'https://api.push.apple.com'
const BUNDLE_ID = 'com.blakeMatt.OnTrack'

const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

// --- base64url ---
function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

// --- .p8 PEM (PKCS8) -> DER bytes ---
function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '')
  const bin = atob(body)
  const der = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i)
  return der
}

// --- APNs JWT (ES256), best-effort cached within a warm worker ---
let cachedKey: CryptoKey | null = null
let cachedJwt: { token: string; iat: number } | null = null

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedJwt && now - cachedJwt.iat < 3000) return cachedJwt.token // reuse < ~50m
  if (!cachedKey) {
    cachedKey = await crypto.subtle.importKey(
      'pkcs8', pemToDer(APNS_PRIVATE_KEY),
      { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'],
    )
  }
  const signingInput = `${b64url(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID }))}.${b64url(JSON.stringify({ iss: APNS_TEAM_ID, iat: now }))}`
  // Web Crypto ECDSA returns raw R||S (JOSE) — exactly what JWS ES256 needs.
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, cachedKey,
    new TextEncoder().encode(signingInput),
  )
  const token = `${signingInput}.${b64url(new Uint8Array(sig))}`
  cachedJwt = { token, iat: now }
  return token
}

async function sendApns(token: string, title: string, body: string): Promise<void> {
  const jwt = await getApnsJwt()
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-topic': BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify({ aps: { alert: { title, body }, sound: 'default' } }),
  })
  const txt = await res.text().catch(() => '')
  console.log(`[push] APNs status=${res.status} token=${token.slice(0,8)}... body=${txt}`)
  if (res.status === 410 || res.status === 400) {
    if (res.status === 410 || txt.includes('BadDeviceToken') || txt.includes('Unregistered')) {
      await admin.from('profiles').update({ push_token: null }).eq('push_token', token)
    } else {
      console.error(`[push] APNs ${res.status}: ${txt}`)
    }
  } else if (!res.ok) {
    console.error(`[push] APNs ${res.status}: ${txt}`)
  }
}

// --- profile / session helpers (service role, bypasses RLS) ---
async function getProfile(id: string): Promise<{ push_token: string | null; display_name: string | null } | null> {
  const { data } = await admin.from('profiles').select('push_token, display_name').eq('id', id).maybeSingle()
  return data ?? null
}
async function getSessionCreator(sessionId: string): Promise<string | null> {
  const { data } = await admin.from('sessions').select('created_by').eq('id', sessionId).maybeSingle()
  return data?.created_by ?? null
}

// --- caller must be service_role ---
function isServiceRole(req: Request): boolean {
  const m = (req.headers.get('Authorization') ?? '').match(/^Bearer\s+(.+)$/i)
  if (!m) return false
  const token = m[1].trim()
  // New sb_secret_ opaque keys: compare directly against injected service role key
  if (token === SERVICE_ROLE) return true
  // Legacy JWT: decode and check role claim
  try {
    const seg = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(seg)).role === 'service_role'
  } catch { return false }
}

type Copy = { title: string; body: string }

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 })
  if (!isServiceRole(req)) return new Response('forbidden', { status: 401 })

  const { type, table, record, old_record } = await req.json()
  const sends: Promise<void>[] = []

  // push to one recipient, resolving the actor's display name; skips self-notify
  const push = async (recipientId: string | null | undefined, actorId: string | null | undefined, make: (name: string) => Copy) => {
    if (!recipientId || recipientId === actorId) return
    const recip = await getProfile(recipientId)
    if (!recip?.push_token) return
    const name = actorId ? (await getProfile(actorId))?.display_name ?? 'Someone' : 'Someone'
    const { title, body } = make(name)
    await sendApns(recip.push_token, title, body)
  }

  switch (table) {
    case 'friendships':
      if (type === 'INSERT' && record.status === 'pending') {
        sends.push(push(record.receiver_id, record.requester_id, (n) => ({ title: 'New friend request', body: `${n} wants to be your friend` })))
      } else if (type === 'UPDATE' && old_record?.status === 'pending' && record.status === 'accepted') {
        sends.push(push(record.requester_id, record.receiver_id, (n) => ({ title: 'Friend request accepted', body: `${n} accepted your friend request` })))
      }
      break
    case 'rsvps': {
      const creator = await getSessionCreator(record.session_id)
      sends.push(push(creator, record.user_id, (n) => ({ title: 'Session RSVP', body: `${n} responded to your session` })))
      break
    }
    case 'group_messages': {
      if (type === 'INSERT') {
        const { data: members } = await admin.from('group_members').select('user_id').eq('group_id', record.group_id)
        const senderName = (await getProfile(record.user_id))?.display_name ?? 'Someone'
        const preview = `${senderName}: ${record.content ?? ''}`.slice(0, 180)
        for (const m of members ?? []) {
          if (m.user_id === record.user_id) continue
          sends.push((async () => {
            const p = await getProfile(m.user_id)
            if (p?.push_token) await sendApns(p.push_token, 'New message', preview)
          })())
        }
      }
      break
    }
    case 'habit_members':
      if (type === 'INSERT' && record.status === 'pending' && record.invited_by && record.invited_by !== record.user_id) {
        sends.push(push(record.user_id, record.invited_by, (n) => ({ title: 'Habit invite', body: `${n} invited you to a habit` })))
      }
      break
    case 'feed_likes':
      if (type === 'INSERT') {
        sends.push(push(record.target_owner_id, record.liker_id, (n) => ({ title: 'New like', body: `${n} liked your activity` })))
      }
      break
    case 'attendance':
      if (type === 'INSERT') {
        const creator = await getSessionCreator(record.session_id)
        sends.push(push(creator, record.user_id, (n) => ({ title: 'Someone joined', body: `${n} is joining your session` })))
      }
      break
  }

  await Promise.allSettled(sends)
  return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } })
})
