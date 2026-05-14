'use client'

import { weeklyConsistency, type AttendanceRow, type WorkoutImportRow } from '../_lib/workouts'

export function AttendanceCard({
  workouts,
  attendance,
}: {
  workouts: WorkoutImportRow[]
  attendance: AttendanceRow[]
}) {
  const { activeDays, consistencyPct, streak } = weeklyConsistency(workouts, attendance)
  const colour = consistencyPct >= 70 ? 'text-green-400' : consistencyPct >= 40 ? 'text-amber-400' : 'text-red-400'

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Attendance</h3>
      <div className="grid grid-cols-3 gap-2 text-center">
        <div>
          <p className={`text-2xl font-bold ${colour}`}>{consistencyPct}%</p>
          <p className="text-[10px] text-text-muted">7d consistency</p>
        </div>
        <div>
          <p className="text-2xl font-bold">{activeDays}/7</p>
          <p className="text-[10px] text-text-muted">active days</p>
        </div>
        <div>
          <p className="text-2xl font-bold text-accent">{streak}</p>
          <p className="text-[10px] text-text-muted">current streak</p>
        </div>
      </div>
    </div>
  )
}
