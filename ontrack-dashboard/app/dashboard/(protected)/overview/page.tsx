import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { OverviewClient } from '../_components/OverviewClient'
import type { CheckinRow } from '../_lib/correlation'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'
import type { BloodMarkerRow } from '../_lib/bloodMarkers'
import type { PersonalBestRow, WorkoutImportRow } from '../_lib/workouts'
import type { BodyMetricsRow } from '../_lib/bodyMetrics'
import type { JournalEntryRow } from '../_lib/journal'
import type { ProtocolType } from '../_lib/protocolConfig'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'
import { normaliseLayout } from '../_lib/widgets'

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

  const cutoff28 = new Date()
  cutoff28.setDate(cutoff28.getDate() - 28)
  const cutoff28Str = cutoff28.toISOString().slice(0, 10)

  const [
    checkinRes,
    suppRes,
    logRes,
    bloodRes,
    workoutRes,
    pbRes,
    bodyRes,
    journalRes,
    protocolRes,
    codeRes,
    unlockRes,
    layoutRes,
  ] = await Promise.all([
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
    supabase
      .from('blood_markers')
      .select('id, marker, value, units, reference_low, reference_high, collected_at, lab, notes')
      .eq('user_id', user.id)
      .order('collected_at', { ascending: true }),
    supabase
      .from('health_workout_imports')
      .select('id, workout_type, duration_minutes, calories, workout_date, source, created_at')
      .eq('user_id', user.id)
      .gte('workout_date', cutoff28Str),
    supabase
      .from('personal_bests')
      .select('id, category, event_name, value, value_unit, reps, logged_at')
      .eq('user_id', user.id)
      .order('logged_at', { ascending: false })
      .limit(20),
    supabase
      .from('body_metrics')
      .select('id, metric_date, weight_kg, body_fat_pct, muscle_mass_kg, waist_cm, chest_cm, arm_cm, neck_cm, notes, source')
      .eq('user_id', user.id)
      .order('metric_date', { ascending: false })
      .limit(20),
    supabase
      .from('health_journal')
      .select('id, protocol_id, entry_date, week_number, body, tag, created_at')
      .eq('user_id', user.id)
      .order('entry_date', { ascending: false })
      .limit(3),
    supabase
      .from('user_protocols')
      .select('protocol_type, protocol_name, start_date')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
    supabase
      .from('partner_discount_codes')
      .select('id, partner_id, supplement_name_match, discount_code, discount_description, discount_percentage, affiliate_url, is_active, supplement_partners(partner_name, partner_logo_url)')
      .eq('is_active', true),
    supabase
      .from('user_discount_unlocks')
      .select('discount_id, viewed_at, clicked_at')
      .eq('user_id', user.id),
    supabase
      .from('dashboard_layouts')
      .select('widgets')
      .eq('user_id', user.id)
      .maybeSingle(),
  ])

  return (
    <OverviewClient
      userId={user.id}
      initial={(checkinRes.data ?? []) as CheckinRow[]}
      supplements={(suppRes.data ?? []) as SupplementRow[]}
      initialLogs={(logRes.data ?? []) as SupplementLogRow[]}
      bloodMarkers={(bloodRes.data ?? []) as BloodMarkerRow[]}
      workouts={(workoutRes.data ?? []) as WorkoutImportRow[]}
      personalBests={(pbRes.data ?? []) as PersonalBestRow[]}
      bodyMetrics={(bodyRes.data ?? []) as BodyMetricsRow[]}
      journal={(journalRes.data ?? []) as JournalEntryRow[]}
      protocolType={(protocolRes.data?.protocol_type as ProtocolType | null) ?? null}
      protocolName={(protocolRes.data?.protocol_name as string | null) ?? null}
      protocolStartDate={(protocolRes.data?.start_date as string | null) ?? null}
      partnerCodes={(codeRes.data ?? []) as unknown as PartnerCodeRow[]}
      unlocks={(unlockRes.data ?? []) as DiscountUnlock[]}
      layout={normaliseLayout(layoutRes.data?.widgets)}
    />
  )
}
