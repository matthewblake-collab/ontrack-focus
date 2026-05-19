import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { ProtocolsClient } from '../_components/ProtocolsClient'

export const dynamic = 'force-dynamic'

export type ActiveProtocol = {
  id: string
  protocol_type: string | null
  protocol_name: string | null
  start_date: string | null
  end_date: string | null
  goal: string | null
  notes: string | null
  config: Record<string, unknown> | null
}

export type BloodMarkerRecord = {
  id: string
  marker: string
  value: number
  units: string | null
  reference_low: number | null
  reference_high: number | null
  collected_at: string
  lab: string | null
  notes: string | null
}

export type JournalRecord = {
  id: string
  protocol_id: string | null
  entry_date: string
  week_number: number | null
  body: string
  tag: string | null
}

export type BodyMetricRecord = {
  id: string
  metric_date: string
  weight_kg: number | null
  body_fat_pct: number | null
  waist_cm: number | null
}

export default async function ProtocolsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const [protocolRes, markersRes, journalRes, metricsRes] = await Promise.all([
    supabase
      .from('user_protocols')
      .select('id, protocol_type, protocol_name, start_date, end_date, goal, notes, config')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
    supabase
      .from('blood_markers')
      .select('id, marker, value, units, reference_low, reference_high, collected_at, lab, notes')
      .eq('user_id', user.id)
      .order('collected_at', { ascending: true }),
    supabase
      .from('health_journal')
      .select('id, protocol_id, entry_date, week_number, body, tag')
      .eq('user_id', user.id)
      .order('entry_date', { ascending: false }),
    supabase
      .from('body_metrics')
      .select('id, metric_date, weight_kg, body_fat_pct, waist_cm')
      .eq('user_id', user.id)
      .order('metric_date', { ascending: false }),
  ])

  const toNum = (v: unknown): number | null => {
    if (v === null || v === undefined) return null
    const n = typeof v === 'string' ? parseFloat(v) : (v as number)
    return Number.isFinite(n) ? n : null
  }

  const protocol = (protocolRes.data ?? null) as ActiveProtocol | null
  const markers: BloodMarkerRecord[] = (markersRes.data ?? []).map((r: Record<string, unknown>) => ({
    id: r.id as string,
    marker: r.marker as string,
    value: toNum(r.value) ?? 0,
    units: (r.units as string | null) ?? null,
    reference_low: toNum(r.reference_low),
    reference_high: toNum(r.reference_high),
    collected_at: r.collected_at as string,
    lab: (r.lab as string | null) ?? null,
    notes: (r.notes as string | null) ?? null,
  }))
  const journal = (journalRes.data ?? []) as JournalRecord[]
  const metrics: BodyMetricRecord[] = (metricsRes.data ?? []).map((r: Record<string, unknown>) => ({
    id: r.id as string,
    metric_date: r.metric_date as string,
    weight_kg: toNum(r.weight_kg),
    body_fat_pct: toNum(r.body_fat_pct),
    waist_cm: toNum(r.waist_cm),
  }))

  return (
    <ProtocolsClient
      userId={user.id}
      protocol={protocol}
      markers={markers}
      journal={journal}
      metrics={metrics}
    />
  )
}
