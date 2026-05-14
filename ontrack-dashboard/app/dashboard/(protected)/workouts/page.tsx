import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { WeeklyVolumeChart } from '../_components/WeeklyVolumeChart'
import { WorkoutTypeDonut } from '../_components/WorkoutTypeDonut'
import { ImportStatusCard } from '../_components/ImportStatusCard'
import { AttendanceCard } from '../_components/AttendanceCard'
import type { AttendanceRow, WorkoutImportRow } from '../_lib/workouts'

export const dynamic = 'force-dynamic'

export default async function WorkoutsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - 120)
  const cutoffStr = cutoff.toISOString().slice(0, 10)

  const [workoutsRes, attendanceRes] = await Promise.all([
    supabase
      .from('health_workout_imports')
      .select('id, workout_type, duration_minutes, calories, workout_date, source, created_at')
      .eq('user_id', user.id)
      .gte('workout_date', cutoffStr)
      .order('workout_date', { ascending: false }),
    supabase
      .from('attendance')
      .select('attended, marked_at')
      .eq('user_id', user.id)
      .gte('marked_at', cutoff.toISOString()),
  ])

  const workouts = (workoutsRes.data ?? []) as WorkoutImportRow[]
  const attendance = (attendanceRes.data ?? []) as AttendanceRow[]

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">Workouts</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <AttendanceCard workouts={workouts} attendance={attendance} />
        <ImportStatusCard rows={workouts} />
      </div>
      <WeeklyVolumeChart rows={workouts} />
      <WorkoutTypeDonut rows={workouts} />
    </div>
  )
}
