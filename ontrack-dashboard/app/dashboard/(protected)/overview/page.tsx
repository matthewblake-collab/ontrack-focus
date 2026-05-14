import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { OverviewClient } from '../_components/OverviewClient'
import type { CheckinRow } from '../_lib/correlation'

export const dynamic = 'force-dynamic'

export default async function OverviewPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - 60)
  const cutoffStr = cutoff.toISOString().slice(0, 10)

  const { data } = await supabase
    .from('daily_checkins')
    .select('checkin_date, sleep, energy, wellbeing, mood, stress')
    .eq('user_id', user.id)
    .gte('checkin_date', cutoffStr)
    .order('checkin_date', { ascending: false })

  const initial = (data ?? []) as CheckinRow[]

  return <OverviewClient userId={user.id} initial={initial} />
}
