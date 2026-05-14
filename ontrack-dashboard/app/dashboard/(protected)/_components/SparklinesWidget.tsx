'use client'

import { LineChart, Line, ResponsiveContainer, YAxis } from 'recharts'
import type { CheckinRow, MetricKey } from '../_lib/correlation'

const metrics: { key: MetricKey; label: string }[] = [
  { key: 'sleep',     label: 'Sleep' },
  { key: 'energy',    label: 'Energy' },
  { key: 'wellbeing', label: 'Wellbeing' },
  { key: 'mood',      label: 'Mood' },
  { key: 'stress',    label: 'Stress' },
]

export function SparklinesWidget({ rows }: { rows: CheckinRow[] }) {
  const last7 = [...rows]
    .sort((a, b) => a.checkin_date.localeCompare(b.checkin_date))
    .slice(-7)

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Last 7 days</h3>
      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {metrics.map(m => {
          const data = last7.map(r => ({ d: r.checkin_date, v: r[m.key] }))
          const latest = data.length > 0 ? data[data.length - 1].v : null
          return (
            <div key={m.key} className="bg-surface-2 rounded-lg p-2">
              <div className="flex items-baseline justify-between mb-1">
                <span className="text-[10px] text-text-muted">{m.label}</span>
                <span className="text-xs font-semibold">{latest ?? '—'}</span>
              </div>
              <div className="h-10">
                <ResponsiveContainer>
                  <LineChart data={data}>
                    <YAxis hide domain={[1, 10]} />
                    <Line
                      type="monotone"
                      dataKey="v"
                      stroke="var(--accent)"
                      strokeWidth={1.5}
                      dot={false}
                      isAnimationActive={false}
                      connectNulls
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
