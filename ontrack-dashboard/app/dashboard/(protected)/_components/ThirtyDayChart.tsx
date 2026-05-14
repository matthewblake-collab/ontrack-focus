'use client'

import { useState } from 'react'
import {
  LineChart, Line, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip,
} from 'recharts'
import type { CheckinRow, MetricKey } from '../_lib/correlation'

const metrics: { key: MetricKey; label: string; colour: string }[] = [
  { key: 'sleep',     label: 'Sleep',     colour: '#2dd4a0' },
  { key: 'energy',    label: 'Energy',    colour: '#facc15' },
  { key: 'wellbeing', label: 'Wellbeing', colour: '#60a5fa' },
  { key: 'mood',      label: 'Mood',      colour: '#c084fc' },
  { key: 'stress',    label: 'Stress',    colour: '#fb7185' },
]

const RANGES = [7, 14, 30] as const
type Range = typeof RANGES[number]

export function ThirtyDayChart({ rows }: { rows: CheckinRow[] }) {
  const [enabled, setEnabled] = useState<Record<MetricKey, boolean>>({
    sleep: true,
    energy: true,
    wellbeing: true,
    mood: false,
    stress: false,
  })
  const [range, setRange] = useState<Range>(30)

  const chartData = [...rows]
    .sort((a, b) => a.checkin_date.localeCompare(b.checkin_date))
    .slice(-range)
    .map(r => ({
      d: r.checkin_date.slice(5),
      sleep: r.sleep,
      energy: r.energy,
      wellbeing: r.wellbeing,
      mood: r.mood,
      stress: r.stress,
    }))

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
        <h3 className="text-sm font-medium">Trends</h3>
        <div className="flex gap-1">
          {RANGES.map(d => (
            <button
              key={d}
              onClick={() => setRange(d)}
              className={`px-2 py-0.5 rounded text-[11px] transition-colors ${
                range === d ? 'bg-accent text-bg' : 'bg-surface-2 text-text-dim hover:text-white'
              }`}
            >
              {d}d
            </button>
          ))}
        </div>
      </div>
      <div className="flex flex-wrap gap-1.5 mb-3">
        {metrics.map(m => (
          <button
            key={m.key}
            onClick={() => setEnabled(e => ({ ...e, [m.key]: !e[m.key] }))}
            className={`px-2 py-0.5 rounded text-[11px] border transition-opacity ${
              enabled[m.key] ? '' : 'opacity-40'
            }`}
            style={{ borderColor: m.colour, color: enabled[m.key] ? m.colour : 'var(--text-muted)' }}
          >
            {m.label}
          </button>
        ))}
      </div>
      <div className="h-56">
        <ResponsiveContainer>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis dataKey="d" stroke="var(--text-muted)" fontSize={10} />
            <YAxis domain={[0, 10]} stroke="var(--text-muted)" fontSize={10} />
            <Tooltip
              contentStyle={{
                background: 'var(--surface)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 8,
                fontSize: 12,
              }}
            />
            {metrics.map(m =>
              enabled[m.key] ? (
                <Line
                  key={m.key}
                  type="monotone"
                  dataKey={m.key}
                  stroke={m.colour}
                  strokeWidth={1.5}
                  dot={false}
                  isAnimationActive={false}
                  connectNulls
                />
              ) : null
            )}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
