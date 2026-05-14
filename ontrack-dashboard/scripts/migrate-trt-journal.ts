/**
 * F8 — TRT journal migration
 *
 * Reads trt.journal_entries from aboedqgvxylyyocawqxo and inserts into
 * public.health_journal in wqkisslixduowewuaiae, linked to Matt's
 * active TRT user_protocols row (creates one if missing).
 *
 * Idempotent: F1 added a unique index on
 *   health_journal(user_id, entry_date, week_number, md5(body))
 * so re-runs skip duplicates.
 *
 * === SAME PRE-STEPS AS migrate-trt-bloods.ts ===
 * Legacy project must expose the `trt` schema + grant `service_role`
 * usage/select on it. Set the same env vars.
 *
 * Run:
 *   npx tsx scripts/migrate-trt-journal.ts
 */

import { createClient } from '@supabase/supabase-js'

type LegacyJournal = {
  entry_date: string
  week_number: number | null
  body: string
  tag: string | null
}

async function main() {
  const oldUrl = process.env.OLD_PROJECT_URL
  const oldKey = process.env.OLD_SERVICE_ROLE
  const newUrl = process.env.NEW_PROJECT_URL
  const newKey = process.env.NEW_SERVICE_ROLE
  const mattEmail = process.env.MATT_EMAIL

  if (!oldUrl || !oldKey || !newUrl || !newKey || !mattEmail) {
    console.error('Missing required env vars.')
    process.exit(1)
  }

  // 1. Fetch legacy journal entries
  const oldClient = createClient(oldUrl, oldKey, {
    db: { schema: 'trt' },
  })
  const { data: entries, error: readError } = await oldClient
    .from('journal_entries')
    .select('entry_date, week_number, body, tag')

  if (readError) {
    console.error('Failed to read trt.journal_entries:', readError.message)
    console.error('Did you expose the trt schema + grant service_role?')
    process.exit(1)
  }
  if (!entries || entries.length === 0) {
    console.log('No rows found in trt.journal_entries.')
    return
  }
  console.log(`Read ${entries.length} legacy journal rows.`)

  // 2. Resolve Matt's UUID
  const newAdmin = createClient(newUrl, newKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { data: usersList, error: usersError } = await newAdmin.auth.admin.listUsers({ perPage: 200 })
  if (usersError) {
    console.error('listUsers failed:', usersError.message)
    process.exit(1)
  }
  const matt = usersList.users.find(u => u.email?.toLowerCase() === mattEmail.toLowerCase())
  if (!matt) {
    console.error(`Matt not found by email ${mattEmail}`)
    process.exit(1)
  }
  console.log(`Matt resolved: ${matt.id}`)

  // 3. Find or create an active TRT user_protocols row
  const { data: existingProtocol } = await newAdmin
    .from('user_protocols')
    .select('id, start_date')
    .eq('user_id', matt.id)
    .eq('protocol_type', 'trt')
    .eq('is_active', true)
    .maybeSingle()

  let protocolId: string
  if (existingProtocol?.id) {
    protocolId = existingProtocol.id
    console.log(`Using existing TRT protocol: ${protocolId}`)
  } else {
    // Earliest entry_date drives start_date
    const earliest = (entries as LegacyJournal[])
      .map(e => e.entry_date)
      .filter(Boolean)
      .sort()[0] ?? '2025-11-05'

    // Deactivate any other active protocols first
    await newAdmin
      .from('user_protocols')
      .update({ is_active: false })
      .eq('user_id', matt.id)
      .eq('is_active', true)

    const { data: newProtocol, error: insertProtocolError } = await newAdmin
      .from('user_protocols')
      .insert({
        user_id: matt.id,
        protocol_type: 'trt',
        protocol_name: 'TRT — Cycle 1',
        start_date: earliest,
        is_active: true,
        goal: 'Migrated from legacy TRT Journey app',
      })
      .select('id')
      .single()
    if (insertProtocolError || !newProtocol) {
      console.error('Failed to create TRT protocol:', insertProtocolError?.message)
      process.exit(1)
    }
    protocolId = newProtocol.id
    console.log(`Created TRT protocol: ${protocolId} (start=${earliest})`)
  }

  // 4. Upsert journal entries
  const rows = (entries as LegacyJournal[])
    .filter(e => e.body && e.entry_date)
    .map(e => ({
      user_id: matt.id,
      protocol_id: protocolId,
      entry_date: e.entry_date,
      week_number: e.week_number,
      body: e.body,
      tag: e.tag ?? 'general',
    }))

  // Insert in batches to avoid huge requests; ignore unique-index conflicts
  const batchSize = 50
  let inserted = 0
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize)
    const { error: writeError, count } = await newAdmin
      .from('health_journal')
      .upsert(batch, {
        onConflict: 'user_id,entry_date,week_number,md5(body)',
        ignoreDuplicates: true,
        count: 'exact',
      })
    if (writeError) {
      // Fallback: PostgREST may not accept expression-based onConflict.
      // Insert one-by-one with conflict-ignored.
      for (const row of batch) {
        const { error: oneError } = await newAdmin.from('health_journal').insert(row)
        if (!oneError) inserted++
        else if (!/duplicate key/i.test(oneError.message)) {
          console.error('Row insert failed:', oneError.message)
        }
      }
    } else {
      inserted += count ?? batch.length
    }
  }
  console.log(`Inserted/upserted ${inserted} of ${rows.length} journal rows.`)
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
