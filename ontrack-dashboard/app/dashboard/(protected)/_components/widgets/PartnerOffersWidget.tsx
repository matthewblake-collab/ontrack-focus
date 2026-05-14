'use client'

import Link from 'next/link'
import type { DiscountUnlock, PartnerCodeRow } from '../../_lib/partners'
import { matchPartnerCodes } from '../../_lib/partners'

export function PartnerOffersWidget({
  supplementNames,
  codes,
  unlocks,
}: {
  supplementNames: string[]
  codes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
}) {
  const matched = new Set<string>()
  for (const name of supplementNames) {
    for (const c of matchPartnerCodes(name, codes)) matched.add(c.id)
  }
  const matchedCodes = Array.from(matched)
  const unlockMap = new Map(unlocks.map(u => [u.discount_id, u]))
  const unread = matchedCodes.filter(id => {
    const u = unlockMap.get(id)
    return !u?.viewed_at
  }).length

  if (matchedCodes.length === 0) {
    return (
      <Link href="/dashboard/offers" className="card block text-text-dim text-sm hover:bg-surface-2">
        No partner matches yet →
      </Link>
    )
  }

  return (
    <Link href="/dashboard/offers" className="card block hover:bg-surface-2 transition-colors">
      <p className="text-[10px] text-text-muted uppercase tracking-wide mb-1">Partner Offers</p>
      <div className="flex items-baseline gap-3">
        <span className="text-2xl font-bold text-accent">{matchedCodes.length}</span>
        <span className="text-xs text-text-dim">matched to your stack</span>
      </div>
      {unread > 0 && (
        <p className="text-[10px] text-amber-400 mt-2">{unread} unread discount{unread === 1 ? '' : 's'}</p>
      )}
    </Link>
  )
}
