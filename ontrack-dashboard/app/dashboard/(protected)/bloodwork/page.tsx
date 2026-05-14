import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { BloodworkClient } from '../_components/BloodworkClient'
import type { BloodMarkerRow } from '../_lib/bloodMarkers'
import type { ProtocolType } from '../_lib/protocolConfig'

export const dynamic = 'force-dynamic'

export default async function BloodworkPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const [markersRes, protocolRes] = await Promise.all([
    supabase
      .from('blood_markers')
      .select('id, marker, value, units, reference_low, reference_high, collected_at, lab, notes')
      .eq('user_id', user.id)
      .order('collected_at', { ascending: true }),
    supabase
      .from('user_protocols')
      .select('protocol_type')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  const rows = (markersRes.data ?? []) as BloodMarkerRow[]
  const protocolType = (protocolRes.data?.protocol_type ?? null) as ProtocolType | null

  return <BloodworkClient userId={user.id} initial={rows} protocolType={protocolType} />
}
