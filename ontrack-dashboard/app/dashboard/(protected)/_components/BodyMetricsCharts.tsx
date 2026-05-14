'use client'

import {
  LineChart, Line, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip,
} from 'recharts'
import type { BodyMetricsRow } from '../_lib/bodyMetrics'

export function BodyMetricsCharts({ rows }: { rows: BodyMetricsRow[] }) {
  if (rows.length === 0) return null
  const sorted = [...rows].sort((a, b) => a.metric_date.localeCompare(b.metric_date))
  const data = sorted.map(r => ({
    d: r.metric_date.slice(5),
    weight: r.weight_kg,
    bf: r.body_fat_pct,
  }))

  const hasWeight = data.some(d => d.weight !== null)
  const hasBf = data.some(d => d.bf !== null)

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
      {hasWeight && (
        <div className="card">
          <h3 className="text-sm font-medium mb-3">Weight (kg)</h3>
          <div className="h-48">
            <ResponsiveContainer>
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="d" stroke="var(--text-muted)" fontSize={10} />
                <YAxis stroke="var(--text-muted)" fontSize={10} domain={['dataMin - 1', 'dataMax + 1']} />
                <Tooltip
                  contentStyle={{
                    background: 'var(--surface)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: 8,
                    fontSize: 12,
                  }}
                />
                <Line type="monotone" dataKey="weight" stroke="var(--accent)" strokeWidth={1.8} dot connectNulls isAnimationActive={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
      {hasBf && (
        <div className="card">
          <h3 className="text-sm font-medium mb-3">Body fat (%)</h3>
          <div className="h-48">
            <ResponsiveContainer>
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="d" stroke="var(--text-muted)" fontSize={10} />
                <YAxis stroke="var(--text-muted)" fontSize={10} domain={['dataMin - 1', 'dataMax + 1']} />
                <Tooltip
                  contentStyle={{
                    background: 'var(--surface)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: 8,
                    fontSize: 12,
                  }}
                />
                <Line type="monotone" dataKey="bf" stroke="#facc15" strokeWidth={1.8} dot connectNulls isAnimationActive={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  )
}
