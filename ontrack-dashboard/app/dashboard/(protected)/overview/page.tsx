import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { OverviewClient } from '../_components/OverviewClient'
import type { CheckinRow } from '../_lib/correlation'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'

export const dynamic = 'force-dynamic'

export default async function OverviewPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const cutoff60 = new Date()
  cutoff60.setDate(cutoff60.getDate() - 60)
  const cutoff60Str = cutoff60.toISOString().slice(0, 10)

  const cutoff7 = new Date()
  cutoff7.setDate(cutoff7.getDate() - 7)
  const cutoff7Str = cutoff7.toISOString().slice(0, 10)

  const [checkinRes, suppRes, logRes] = await Promise.all([
    supabase
      .from('daily_checkins')
      .select('checkin_date, sleep, energy, wellbeing, mood, stress')
      .eq('user_id', user.id)
      .gte('checkin_date', cutoff60Str)
      .order('checkin_date', { ascending: false }),
    supabase
      .from('supplements')
      .select('id, name, dose, timing, days_of_week, notes, is_active, in_protocol, start_date')
      .eq('user_id', user.id)
      .eq('is_active', true),
    supabase
      .from('supplement_logs')
      .select('supplement_id, taken, taken_at')
      .eq('user_id', user.id)
      .gte('taken_at', cutoff7Str),
  ])

  const initial = (checkinRes.data ?? []) as CheckinRow[]
  const supplements = (suppRes.data ?? []) as SupplementRow[]
  const initialLogs = (logRes.data ?? []) as SupplementLogRow[]

  return (
    <OverviewClient
      userId={user.id}
      initial={initial}
      supplements={supplements}
      initialLogs={initialLogs}
    />
  )
}
