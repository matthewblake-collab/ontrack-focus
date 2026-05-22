'use client'

import { bestCorrelation, correlationSentence, type CheckinRow } from '../_lib/correlation'

export function CorrelationStrip({ rows }: { rows: CheckinRow[] }) {
  const pair = bestCorrelation(rows)
  if (!pair) {
    return (
      <div className="card text-xs text-text-dim">
        Log at least 5 check-ins to surface correlations.
      </div>
    )
  }
  const abs = Math.abs(pair.r)
  const strength = abs >= 0.6 ? 'strong' : abs >= 0.3 ? 'moderate' : 'weak'
  return (
    <div className="card border border-accent/30 bg-accent/5">
      <div className="flex items-baseline gap-2">
        <span className="text-[10px] text-accent uppercase tracking-wide">Insight</span>
        <span className="text-[10px] text-text-muted">{strength} signal</span>
      </div>
      <p className="text-sm mt-1 text-text-dim">{correlationSentence(pair)}</p>
    </div>
  )
}
