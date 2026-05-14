import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { BiometricsClient } from '../_components/BiometricsClient'
import type { BodyMetricsRow } from '../_lib/bodyMetrics'

export const dynamic = 'force-dynamic'

export default async function BiometricsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const { data } = await supabase
    .from('body_metrics')
    .select('id, metric_date, weight_kg, body_fat_pct, muscle_mass_kg, waist_cm, chest_cm, arm_cm, neck_cm, notes, source')
    .eq('user_id', user.id)
    .order('metric_date', { ascending: true })

  const rows = (data ?? []) as BodyMetricsRow[]

  return <BiometricsClient userId={user.id} initial={rows} />
}
