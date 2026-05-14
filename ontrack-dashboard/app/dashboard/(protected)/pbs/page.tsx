import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { PBCardsByCategory } from '../_components/PBCardsByCategory'
import { PBTimelineChart } from '../_components/PBTimelineChart'
import type { PersonalBestRow } from '../_lib/workouts'

export const dynamic = 'force-dynamic'

export default async function PBsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const [pbsRes, protocolRes] = await Promise.all([
    supabase
      .from('personal_bests')
      .select('id, category, event_name, value, value_unit, reps, logged_at')
      .eq('user_id', user.id)
      .order('logged_at', { ascending: false }),
    supabase
      .from('user_protocols')
      .select('protocol_name, start_date')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  const rows = (pbsRes.data ?? []) as PersonalBestRow[]
  const start = (protocolRes.data?.start_date as string | null) ?? null
  const name = (protocolRes.data?.protocol_name as string | null) ?? null

  const sinceStart = start ? rows.filter(r => r.logged_at >= start).length : 0

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Personal Bests</h2>
        {name && (
          <span className="text-xs text-accent">
            {sinceStart} PB{sinceStart === 1 ? '' : 's'} since starting {name}
          </span>
        )}
      </div>
      <PBTimelineChart rows={rows} protocolStartDate={start} protocolName={name} />
      <PBCardsByCategory rows={rows} />
    </div>
  )
}
