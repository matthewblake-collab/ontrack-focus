'use client'

import { Pencil } from 'lucide-react'
import { computeAdherence, pctColour, type SupplementLogRow, type SupplementRow } from '../_lib/adherence'
import { matchPartnerCodes, type DiscountUnlock, type PartnerCodeRow } from '../_lib/partners'
import { PartnerBadge } from './PartnerBadge'

export function StackList({
  userId,
  supplements,
  logs,
  codes,
  unlocks,
  onEdit,
}: {
  userId: string
  supplements: SupplementRow[]
  logs: SupplementLogRow[]
  codes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
  onEdit: (s: SupplementRow) => void
}) {
  if (supplements.length === 0) {
    return <div className="card text-text-dim text-sm">No active supplements.</div>
  }

  return (
    <div className="space-y-2">
      {supplements.map(s => {
        const { pct, streakDays } = computeAdherence(s, logs)
        const matched = matchPartnerCodes(s.name, codes)
        return (
          <div key={s.id} className="card flex items-start gap-3">
            <div className="flex-1 min-w-0">
              <div className="flex items-baseline gap-2 flex-wrap">
                <h4 className="font-medium truncate">{s.name}</h4>
                {s.in_protocol && (
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-accent/15 text-accent">protocol</span>
                )}
              </div>
              <p className="text-xs text-text-dim mt-0.5">
                {[s.dose, s.timing].filter(Boolean).join(' · ') || 'Not set'}
              </p>
              {s.notes && (
                <p className="text-xs text-text-muted mt-1 line-clamp-2">{s.notes}</p>
              )}
              <div className="flex items-center gap-3 mt-2 text-xs">
                <span className={pctColour(pct)}>{pct}% (30d)</span>
                <span className="text-text-muted">{streakDays}d streak</span>
              </div>
              {matched.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-2">
                  {matched.map(c => {
                    const unlock = unlocks.find(u => u.discount_id === c.id) ?? null
                    return <PartnerBadge key={c.id} userId={userId} code={c} initialUnlock={unlock} />
                  })}
                </div>
              )}
            </div>
            <button
              onClick={() => onEdit(s)}
              className="text-text-muted hover:text-white shrink-0"
              aria-label="Edit supplement"
            >
              <Pencil size={14} />
            </button>
          </div>
        )
      })}
    </div>
  )
}
