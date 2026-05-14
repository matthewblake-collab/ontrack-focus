'use client'

import Link from 'next/link'
import type { PersonalBestRow } from '../../_lib/workouts'

export function PersonalBestsWidget({
  rows,
  protocolStartDate,
  protocolName,
}: {
  rows: PersonalBestRow[]
  protocolStartDate: string | null
  protocolName: string | null
}) {
  if (rows.length === 0) {
    return (
      <Link href="/dashboard/pbs" className="card block text-text-dim text-sm hover:bg-surface-2">
        No PBs yet →
      </Link>
    )
  }
  const sorted = [...rows].sort((a, b) => b.logged_at.localeCompare(a.logged_at))
  const latest = sorted[0]
  const sinceStart = protocolStartDate
    ? rows.filter(r => r.logged_at >= protocolStartDate).length
    : 0

  return (
    <Link href="/dashboard/pbs" className="card block hover:bg-surface-2 transition-colors">
      <p className="text-[10px] text-text-muted uppercase tracking-wide mb-1">Personal Bests</p>
      <p className="text-sm font-medium truncate">{latest.event_name}</p>
      <p className="text-xl font-bold mt-1">
        {latest.value}
        {latest.value_unit && <span className="text-xs text-text-muted ml-1">{latest.value_unit}</span>}
      </p>
      {protocolStartDate && protocolName && (
        <p className="text-[10px] text-accent mt-2">
          {sinceStart} since starting {protocolName}
        </p>
      )}
    </Link>
  )
}
