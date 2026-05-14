'use client'

import { useState } from 'react'
import { useRealtime } from '../_lib/useRealtime'
import type { BodyMetricsRow } from '../_lib/bodyMetrics'
import { BodyMetricsForm } from './BodyMetricsForm'
import { BodyMetricsCharts } from './BodyMetricsCharts'

export function BiometricsClient({
  userId,
  initial,
}: {
  userId: string
  initial: BodyMetricsRow[]
}) {
  const [rows, setRows] = useState<BodyMetricsRow[]>(initial)

  useRealtime<BodyMetricsRow>({
    userId,
    table: 'body_metrics',
    event: 'INSERT',
    onChange: row => setRows(prev => [...prev, row]),
  })

  const latest = rows.length > 0
    ? [...rows].sort((a, b) => b.metric_date.localeCompare(a.metric_date))[0]
    : null

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Body Metrics</h2>
        <BodyMetricsForm userId={userId} onSaved={row => setRows(prev => [...prev, row])} />
      </div>
      {latest ? (
        <div className="card">
          <p className="text-xs text-text-muted">Latest · {latest.metric_date}</p>
          <div className="grid grid-cols-3 gap-3 mt-2">
            {latest.weight_kg !== null && (
              <div><p className="text-xl font-bold">{latest.weight_kg}<span className="text-xs text-text-muted ml-1">kg</span></p><p className="text-[10px] text-text-muted">Weight</p></div>
            )}
            {latest.body_fat_pct !== null && (
              <div><p className="text-xl font-bold">{latest.body_fat_pct}<span className="text-xs text-text-muted ml-1">%</span></p><p className="text-[10px] text-text-muted">Body fat</p></div>
            )}
            {latest.muscle_mass_kg !== null && (
              <div><p className="text-xl font-bold">{latest.muscle_mass_kg}<span className="text-xs text-text-muted ml-1">kg</span></p><p className="text-[10px] text-text-muted">Muscle</p></div>
            )}
          </div>
        </div>
      ) : (
        <div className="card text-text-dim text-sm">No body metrics logged yet.</div>
      )}
      <BodyMetricsCharts rows={rows} />
    </div>
  )
}
