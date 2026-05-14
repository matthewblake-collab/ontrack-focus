'use client'

import {
  LineChart, Line, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceArea,
} from 'recharts'
import type { BloodMarkerRow } from '../_lib/bloodMarkers'
import { markerLabel } from '../_lib/bloodMarkers'

export function MarkerTrendChart({ marker, rows }: { marker: string; rows: BloodMarkerRow[] }) {
  if (rows.length === 0) return null

  const data = rows.map(r => ({
    d: r.collected_at.slice(0, 10),
    v: r.value,
  }))
  const refLow = rows.find(r => r.reference_low !== null)?.reference_low ?? undefined
  const refHigh = rows.find(r => r.reference_high !== null)?.reference_high ?? undefined

  const values = data.map(d => d.v)
  const dataMin = Math.min(...values, refLow ?? Number.POSITIVE_INFINITY)
  const dataMax = Math.max(...values, refHigh ?? Number.NEGATIVE_INFINITY)
  const pad = Math.max((dataMax - dataMin) * 0.15, 0.5)
  const yMin = Math.max(0, dataMin - pad)
  const yMax = dataMax + pad

  return (
    <div className="card">
      <h4 className="text-xs font-medium text-text-dim mb-2">{markerLabel(marker)}</h4>
      <div className="h-32">
        <ResponsiveContainer>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
            <XAxis dataKey="d" stroke="var(--text-muted)" fontSize={10} />
            <YAxis domain={[yMin, yMax]} stroke="var(--text-muted)" fontSize={10} />
            <Tooltip
              contentStyle={{
                background: 'var(--surface)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 8,
                fontSize: 12,
              }}
            />
            {refLow !== undefined && refHigh !== undefined && (
              <ReferenceArea y1={refLow} y2={refHigh} fill="#2dd4a0" fillOpacity={0.08} stroke="none" />
            )}
            <Line type="monotone" dataKey="v" stroke="var(--accent)" strokeWidth={1.8} dot isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
