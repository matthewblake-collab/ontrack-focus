'use client'

import {
  ComposedChart, Bar, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts'
import { groupByWeek, type WorkoutImportRow } from '../_lib/workouts'

export function WeeklyVolumeChart({ rows }: { rows: WorkoutImportRow[] }) {
  const data = groupByWeek(rows).slice(-12).map(w => ({
    week: w.weekStart.slice(5),  // MM-DD
    sessions: w.count,
    minutes: w.durationMinutes,
  }))

  if (data.length === 0) {
    return <div className="card text-text-dim text-sm">No workout imports yet.</div>
  }

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Weekly volume (last 12 weeks)</h3>
      <div className="h-56">
        <ResponsiveContainer>
          <ComposedChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis dataKey="week" stroke="var(--text-muted)" fontSize={10} />
            <YAxis yAxisId="left" stroke="var(--text-muted)" fontSize={10} />
            <YAxis yAxisId="right" orientation="right" stroke="var(--text-muted)" fontSize={10} />
            <Tooltip
              contentStyle={{
                background: 'var(--surface)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 8,
                fontSize: 12,
              }}
            />
            <Legend wrapperStyle={{ fontSize: 11 }} />
            <Bar yAxisId="left" dataKey="sessions" fill="#2dd4a0" radius={[3, 3, 0, 0]} />
            <Line yAxisId="right" type="monotone" dataKey="minutes" stroke="#facc15" strokeWidth={1.5} dot />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
