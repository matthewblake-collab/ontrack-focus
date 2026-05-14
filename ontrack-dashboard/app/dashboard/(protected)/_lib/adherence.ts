export type SupplementRow = {
  id: string
  name: string
  dose: string | null
  timing: string | null
  days_of_week: string | null
  notes: string | null
  is_active: boolean
  in_protocol: boolean
  start_date: string | null
}

export type SupplementLogRow = {
  supplement_id: string
  taken: boolean
  taken_at: string  // yyyy-MM-dd
}

export type AdherenceStats = {
  pct: number
  streakDays: number
  takenDays: Set<string>
}

export function todayISO(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${dd}`
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number)
  const dt = new Date(Date.UTC(y, m - 1, d))
  dt.setUTCDate(dt.getUTCDate() + days)
  return dt.toISOString().slice(0, 10)
}

function daysBetween(a: string, b: string): number {
  const ad = new Date(a + 'T00:00:00Z')
  const bd = new Date(b + 'T00:00:00Z')
  return Math.floor((bd.getTime() - ad.getTime()) / 86400000)
}

/** Compute adherence % + current streak for one supplement across the last `days`. */
export function computeAdherence(
  supp: SupplementRow,
  logs: SupplementLogRow[],
  days = 30
): AdherenceStats {
  const today = todayISO()
  const windowStart = addDays(today, -(days - 1))

  const taken = logs.filter(
    l => l.supplement_id === supp.id &&
         l.taken &&
         l.taken_at >= windowStart &&
         l.taken_at <= today
  )
  const takenDays = new Set(taken.map(l => l.taken_at))

  let effectiveStart = windowStart
  if (supp.start_date && supp.start_date > windowStart) {
    effectiveStart = supp.start_date
  }
  const effectiveDays = Math.max(1, daysBetween(effectiveStart, today) + 1)
  const pct = Math.min(100, Math.round((takenDays.size / effectiveDays) * 100))

  let streak = 0
  let cursor = today
  while (takenDays.has(cursor) && cursor >= effectiveStart) {
    streak++
    cursor = addDays(cursor, -1)
  }

  return { pct, streakDays: streak, takenDays }
}

export function pctColour(pct: number): string {
  if (pct >= 80) return 'text-green-400'
  if (pct >= 50) return 'text-amber-400'
  return 'text-red-400'
}
