'use client'

import { addDays, todayISO, type SupplementLogRow, type SupplementRow } from '../_lib/adherence'

function cellColour(pct: number): string {
  if (pct >= 80) return 'bg-green-500/80'
  if (pct >= 50) return 'bg-amber-500/70'
  if (pct > 0) return 'bg-red-500/60'
  return 'bg-surface-2'
}

export function AdherenceHeatmap({
  supplements,
  logs,
  days = 42,
}: {
  supplements: SupplementRow[]
  logs: SupplementLogRow[]
  days?: number
}) {
  const today = todayISO()
  const dayList: string[] = []
  for (let i = days - 1; i >= 0; i--) dayList.push(addDays(today, -i))

  const totalSupps = supplements.length
  const byDay = new Map<string, Set<string>>()
  for (const log of logs) {
    if (!log.taken) continue
    if (!byDay.has(log.taken_at)) byDay.set(log.taken_at, new Set())
    byDay.get(log.taken_at)!.add(log.supplement_id)
  }

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Daily adherence (last {days}d)</h3>
      <div className="grid grid-cols-7 gap-1">
        {dayList.map(d => {
          const taken = byDay.get(d)?.size ?? 0
          const pct = totalSupps === 0 ? 0 : Math.round((taken / totalSupps) * 100)
          return (
            <div
              key={d}
              title={`${d} — ${taken}/${totalSupps} (${pct}%)`}
              className={`aspect-square rounded ${cellColour(pct)}`}
            />
          )
        })}
      </div>
      <div className="flex items-center justify-end gap-2 mt-3 text-[10px] text-text-muted">
        <span>Low</span>
        <span className="w-3 h-3 rounded bg-surface-2" />
        <span className="w-3 h-3 rounded bg-red-500/60" />
        <span className="w-3 h-3 rounded bg-amber-500/70" />
        <span className="w-3 h-3 rounded bg-green-500/80" />
        <span>High</span>
      </div>
    </div>
  )
}
