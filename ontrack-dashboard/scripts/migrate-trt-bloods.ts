/**
 * F6 — TRT bloods migration script
 *
 * Reads all rows from trt.blood_panels in the legacy project
 * (aboedqgvxylyyocawqxo) and inserts them into blood_markers in
 * the OnTrack project (wqkisslixduowewuaiae), keyed on Matt's UUID
 * resolved by email.
 *
 * Idempotent: F1 added a unique index on
 *   blood_markers(user_id, marker, collected_at)
 * so re-runs are safe (ON CONFLICT DO NOTHING via upsert).
 *
 * === BEFORE RUNNING ===
 *
 * The legacy project's PostgREST only exposes `public` + `graphql_public`
 * schemas by default. The `trt` schema must be exposed first:
 *
 *   Supabase Dashboard (aboedqgvxylyyocawqxo)
 *     → Project Settings → API → Exposed schemas
 *     → add `trt` → Save
 *
 * Then export both projects' service_role keys + Matt's email:
 *
 *   export OLD_PROJECT_URL=https://aboedqgvxylyyocawqxo.supabase.co
 *   export OLD_SERVICE_ROLE=...
 *   export NEW_PROJECT_URL=https://wqkisslixduowewuaiae.supabase.co
 *   export NEW_SERVICE_ROLE=...
 *   export MATT_EMAIL=matthew.blake@outlook.com.au
 *
 * And run:
 *
 *   npx tsx scripts/migrate-trt-bloods.ts
 */

import { createClient } from '@supabase/supabase-js'

type LegacyPanel = {
  marker: string
  value: number
  draw_date: string
  label: string | null
  unit: string | null
  ref_low: number | null
  ref_high: number | null
}

async function main() {
  const oldUrl = process.env.OLD_PROJECT_URL
  const oldKey = process.env.OLD_SERVICE_ROLE
  const newUrl = process.env.NEW_PROJECT_URL
  const newKey = process.env.NEW_SERVICE_ROLE
  const mattEmail = process.env.MATT_EMAIL

  if (!oldUrl || !oldKey || !newUrl || !newKey || !mattEmail) {
    console.error('Missing required env vars. See top of file for setup.')
    process.exit(1)
  }

  // 1. Fetch rows from legacy trt.blood_panels via PostgREST Accept-Profile header
  const oldClient = createClient(oldUrl, oldKey, {
    db: { schema: 'trt' },
  })
  const { data: panels, error: readError } = await oldClient
    .from('blood_panels')
    .select('marker, value, draw_date, label, unit, ref_low, ref_high')

  if (readError) {
    console.error('Failed to read trt.blood_panels:', readError.message)
    console.error('Did you expose the trt schema in the legacy project API settings?')
    process.exit(1)
  }
  if (!panels || panels.length === 0) {
    console.log('No rows found in trt.blood_panels.')
    return
  }
  console.log(`Read ${panels.length} legacy panel rows.`)

  // 2. Resolve Matt's UUID in the new project
  const newAdmin = createClient(newUrl, newKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { data: usersList, error: usersError } = await newAdmin.auth.admin.listUsers({ perPage: 200 })
  if (usersError) {
    console.error('auth.admin.listUsers failed:', usersError.message)
    process.exit(1)
  }
  const matt = usersList.users.find(u => u.email?.toLowerCase() === mattEmail.toLowerCase())
  if (!matt) {
    console.error(`Matt not found by email ${mattEmail} in new project.`)
    process.exit(1)
  }
  console.log(`Matt resolved: ${matt.id}`)

  // 3. Map and upsert into blood_markers (idempotent via unique index)
  const rows = (panels as LegacyPanel[]).map(p => ({
    user_id: matt.id,
    marker: p.marker,
    value: p.value,
    collected_at: new Date(`${p.draw_date}T00:00:00Z`).toISOString(),
    notes: p.label,
    units: p.unit,
    reference_low: p.ref_low,
    reference_high: p.ref_high,
  }))

  const { error: writeError, count } = await newAdmin
    .from('blood_markers')
    .upsert(rows, {
      onConflict: 'user_id,marker,collected_at',
      ignoreDuplicates: true,
      count: 'exact',
    })

  if (writeError) {
    console.error('Failed to write blood_markers:', writeError.message)
    process.exit(1)
  }
  console.log(`Upserted ${rows.length} rows (count returned: ${count ?? '?'}).`)
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
