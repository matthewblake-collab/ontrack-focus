'use client'

import Link from 'next/link'
import { groupByWeek, type WorkoutImportRow } from '../../_lib/workouts'

export function WorkoutVolumeWidget({ rows }: { rows: WorkoutImportRow[] }) {
  if (rows.length === 0) {
    return (
      <Link href="/dashboard/workouts" className="card block text-text-dim text-sm hover:bg-surface-2">
        No workouts yet →
      </Link>
    )
  }
  const recent = groupByWeek(rows).slice(-4)
  const totalSessions = recent.reduce((a, w) => a + w.count, 0)
  const totalMinutes = recent.reduce((a, w) => a + w.durationMinutes, 0)

  return (
    <Link href="/dashboard/workouts" className="card block hover:bg-surface-2 transition-colors">
      <p className="text-[10px] text-text-muted uppercase tracking-wide mb-1">Workouts · last 4 weeks</p>
      <div className="flex items-baseline gap-4">
        <div>
          <p className="text-2xl font-bold text-accent">{totalSessions}</p>
          <p className="text-[10px] text-text-muted">sessions</p>
        </div>
        <div>
          <p className="text-2xl font-bold">{Math.round(totalMinutes / 60)}</p>
          <p className="text-[10px] text-text-muted">hours</p>
        </div>
      </div>
    </Link>
  )
}
