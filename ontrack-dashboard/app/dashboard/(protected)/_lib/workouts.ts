export type WorkoutImportRow = {
  id?: string
  workout_type: string | null
  duration_minutes: number | null
  calories: number | null
  workout_date: string  // yyyy-MM-dd TEXT
  source: string | null
  created_at?: string | null
}

export type AttendanceRow = {
  attended: boolean
  marked_at: string | null
}

export type PersonalBestRow = {
  id: string
  category: string
  event_name: string
  value: number
  value_unit: string | null
  reps: number | null
  logged_at: string  // TEXT yyyy-MM-dd
}

/** Start of ISO week (Monday) as yyyy-MM-dd. */
export function isoWeekStart(date: string): string {
  const [y, m, d] = date.split('-').map(Number)
  const dt = new Date(Date.UTC(y, m - 1, d))
  const day = dt.getUTCDay() || 7
  if (day !== 1) dt.setUTCDate(dt.getUTCDate() - (day - 1))
  return dt.toISOString().slice(0, 10)
}

export type WeeklyVolume = {
  weekStart: string
  count: number
  durationMinutes: number
}

export function groupByWeek(rows: WorkoutImportRow[]): WeeklyVolume[] {
  const map = new Map<string, WeeklyVolume>()
  for (const r of rows) {
    const wk = isoWeekStart(r.workout_date)
    const entry = map.get(wk) ?? { weekStart: wk, count: 0, durationMinutes: 0 }
    entry.count += 1
    entry.durationMinutes += r.duration_minutes ?? 0
    map.set(wk, entry)
  }
  return Array.from(map.values()).sort((a, b) => a.weekStart.localeCompare(b.weekStart))
}

export function workoutTypeBreakdown(rows: WorkoutImportRow[]): { name: string; count: number }[] {
  const map = new Map<string, number>()
  for (const r of rows) {
    const key = r.workout_type ?? 'Other'
    map.set(key, (map.get(key) ?? 0) + 1)
  }
  return Array.from(map.entries())
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count)
}

/** Last 7d activity = unique days with a workout import or marked attendance. */
export function weeklyConsistency(
  workouts: WorkoutImportRow[],
  attendance: AttendanceRow[]
): { activeDays: number; consistencyPct: number; streak: number } {
  const today = new Date()
  const todayUTC = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()))
  const sevenAgo = new Date(todayUTC.getTime() - 6 * 86400000)
  const days = new Set<string>()
  for (const w of workouts) {
    if (w.workout_date >= sevenAgo.toISOString().slice(0, 10)) days.add(w.workout_date)
  }
  for (const a of attendance) {
    if (!a.attended || !a.marked_at) continue
    const d = a.marked_at.slice(0, 10)
    if (d >= sevenAgo.toISOString().slice(0, 10)) days.add(d)
  }
  // Streak going back from today
  const allDays = new Set<string>()
  for (const w of workouts) allDays.add(w.workout_date)
  for (const a of attendance) if (a.attended && a.marked_at) allDays.add(a.marked_at.slice(0, 10))

  let streak = 0
  const cursor = new Date(todayUTC.getTime())
  while (allDays.has(cursor.toISOString().slice(0, 10))) {
    streak++
    cursor.setUTCDate(cursor.getUTCDate() - 1)
  }
  return {
    activeDays: days.size,
    consistencyPct: Math.round((days.size / 7) * 100),
    streak,
  }
}

export function pbDaysSinceStart(logged_at: string, start_date: string | null): number | null {
  if (!start_date) return null
  const a = new Date(start_date + 'T00:00:00Z').getTime()
  const b = new Date(logged_at + 'T00:00:00Z').getTime()
  if (isNaN(a) || isNaN(b)) return null
  return Math.floor((b - a) / 86400000)
}
