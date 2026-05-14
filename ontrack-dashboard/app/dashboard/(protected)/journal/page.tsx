import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { JournalClient } from '../_components/JournalClient'
import type { JournalEntryRow } from '../_lib/journal'

export const dynamic = 'force-dynamic'

export default async function JournalPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const [entriesRes, protocolRes] = await Promise.all([
    supabase
      .from('health_journal')
      .select('id, protocol_id, entry_date, week_number, body, tag, created_at')
      .eq('user_id', user.id)
      .order('entry_date', { ascending: false })
      .order('created_at', { ascending: false }),
    supabase
      .from('user_protocols')
      .select('id, protocol_name, start_date')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  const entries = (entriesRes.data ?? []) as JournalEntryRow[]
  const protocolId = (protocolRes.data?.id as string | null) ?? null
  const protocolName = (protocolRes.data?.protocol_name as string | null) ?? null
  const protocolStartDate = (protocolRes.data?.start_date as string | null) ?? null

  return (
    <JournalClient
      userId={user.id}
      initial={entries}
      protocolId={protocolId}
      protocolStartDate={protocolStartDate}
      protocolName={protocolName}
    />
  )
}
