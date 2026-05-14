'use client'

import { computeAdherence, pctColour, type SupplementLogRow, type SupplementRow } from '../_lib/adherence'

/** Compact weekly adherence widget for the Overview page. */
export function AdherenceWidget({
  supplements,
  logs,
}: {
  supplements: SupplementRow[]
  logs: SupplementLogRow[]
}) {
  if (supplements.length === 0) return null
  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Supplement adherence (7d)</h3>
      <div className="space-y-1.5">
        {supplements.slice(0, 6).map(s => {
          const { pct } = computeAdherence(s, logs, 7)
          return (
            <div key={s.id} className="flex items-center justify-between text-xs">
              <span className="truncate flex-1">
                {s.name}
                {s.in_protocol && <span className="text-[9px] text-accent ml-1.5">·protocol</span>}
              </span>
              <span className={`font-medium ${pctColour(pct)}`}>{pct}%</span>
            </div>
          )
        })}
        {supplements.length > 6 && (
          <p className="text-[10px] text-text-muted pt-1">+ {supplements.length - 6} more</p>
        )}
      </div>
    </div>
  )
}
