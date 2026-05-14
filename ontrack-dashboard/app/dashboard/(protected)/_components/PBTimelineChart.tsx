'use client'

import {
  LineChart, Line, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine,
} from 'recharts'
import { pbDaysSinceStart, type PersonalBestRow } from '../_lib/workouts'

export function PBTimelineChart({
  rows,
  protocolStartDate,
  protocolName,
}: {
  rows: PersonalBestRow[]
  protocolStartDate: string | null
  protocolName: string | null
}) {
  if (rows.length < 2) return null

  // X = days since protocol start (negative for pre-start), Y = value
  // Group by event_name; show top 3 events by frequency
  const eventCounts = new Map<string, number>()
  for (const r of rows) eventCounts.set(r.event_name, (eventCounts.get(r.event_name) ?? 0) + 1)
  const topEvents = Array.from(eventCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([name]) => name)

  if (topEvents.length === 0) return null

  const colours = ['#2dd4a0', '#facc15', '#60a5fa']
  const allDays = rows
    .map(r => pbDaysSinceStart(r.logged_at, protocolStartDate))
    .filter((x): x is number => x !== null)
  const minDay = allDays.length > 0 ? Math.min(...allDays) : 0
  const maxDay = allDays.length > 0 ? Math.max(...allDays) : 30

  type Pt = { day: number } & Record<string, number | null>
  const sortedRows = [...rows].sort((a, b) => a.logged_at.localeCompare(b.logged_at))
  const data: Pt[] = []
  for (const r of sortedRows) {
    if (!topEvents.includes(r.event_name)) continue
    const day = pbDaysSinceStart(r.logged_at, protocolStartDate)
    if (day === null) continue
    data.push({ day, [r.event_name]: r.value } as Pt)
  }

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">
        PB progression {protocolName ? `· ${protocolName}` : ''}
      </h3>
      <div className="h-56">
        <ResponsiveContainer>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis
              type="number"
              dataKey="day"
              domain={[minDay, maxDay]}
              stroke="var(--text-muted)"
              fontSize={10}
              label={{ value: 'Days since protocol start', position: 'insideBottom', offset: -3, fontSize: 10, fill: 'var(--text-muted)' }}
            />
            <YAxis stroke="var(--text-muted)" fontSize={10} />
            <Tooltip
              contentStyle={{
                background: 'var(--surface)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 8,
                fontSize: 12,
              }}
            />
            {protocolStartDate && <ReferenceLine x={0} stroke="#2dd4a0" strokeDasharray="3 3" />}
            {topEvents.map((evt, i) => (
              <Line
                key={evt}
                type="monotone"
                dataKey={evt}
                stroke={colours[i]}
                strokeWidth={1.5}
                dot
                connectNulls
                isAnimationActive={false}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
