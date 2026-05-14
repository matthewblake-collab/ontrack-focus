'use client'

import Link from 'next/link'
import type { BodyMetricsRow } from '../../_lib/bodyMetrics'

export function BodyMetricsWidget({ rows }: { rows: BodyMetricsRow[] }) {
  if (rows.length === 0) {
    return (
      <Link href="/dashboard/biometrics" className="card block text-text-dim text-sm hover:bg-surface-2">
        Log body metrics →
      </Link>
    )
  }
  const sorted = [...rows].sort((a, b) => b.metric_date.localeCompare(a.metric_date))
  const latest = sorted[0]

  return (
    <Link href="/dashboard/biometrics" className="card block hover:bg-surface-2 transition-colors">
      <div className="flex items-baseline justify-between mb-1">
        <p className="text-[10px] text-text-muted uppercase tracking-wide">Body Metrics</p>
        <span className="text-[10px] text-text-muted">{latest.metric_date}</span>
      </div>
      <div className="flex items-baseline gap-4 mt-1">
        {latest.weight_kg !== null && (
          <div>
            <p className="text-2xl font-bold text-accent">{latest.weight_kg}</p>
            <p className="text-[10px] text-text-muted">kg</p>
          </div>
        )}
        {latest.body_fat_pct !== null && (
          <div>
            <p className="text-2xl font-bold">{latest.body_fat_pct}</p>
            <p className="text-[10px] text-text-muted">% body fat</p>
          </div>
        )}
      </div>
    </Link>
  )
}
