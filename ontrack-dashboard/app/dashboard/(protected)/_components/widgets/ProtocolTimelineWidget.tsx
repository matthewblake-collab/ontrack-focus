'use client'

import { currentPhase, nextPhase, weekNumber, type ProtocolType } from '../../_lib/protocolConfig'

export function ProtocolTimelineWidget({
  protocolType,
  protocolName,
  startDate,
}: {
  protocolType: ProtocolType | null
  protocolName: string | null
  startDate: string | null
}) {
  if (!protocolType || !startDate) {
    return (
      <div className="card text-text-dim text-sm">
        No active protocol. Set one up in the iOS app.
      </div>
    )
  }
  const wk = weekNumber(startDate)
  const phase = currentPhase(protocolType, wk)
  const upcoming = nextPhase(protocolType, wk)

  return (
    <div className="card">
      <p className="text-[10px] text-text-muted uppercase tracking-wide mb-1">Protocol</p>
      <p className="text-sm font-medium">{protocolName ?? protocolType}</p>
      <div className="flex items-baseline gap-3 mt-2">
        <span className="text-2xl font-bold text-accent">Wk {wk}</span>
        {phase && (
          <span className="text-xs text-text-dim">
            {phase.name} (wk {phase.weekStart}–{phase.weekEnd})
          </span>
        )}
      </div>
      {upcoming && (
        <p className="text-[10px] text-text-muted mt-2">
          Next: {upcoming.name} (week {upcoming.weekStart} — in {upcoming.weekStart - wk}w)
        </p>
      )}
    </div>
  )
}
