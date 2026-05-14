'use client'

import Link from 'next/link'
import { latestByMarker, statusColour, statusFor, type BloodMarkerRow } from '../../_lib/bloodMarkers'
import { PROTOCOL_CONFIGS, type ProtocolType } from '../../_lib/protocolConfig'

export function BloodworkSummaryWidget({
  rows,
  protocolType,
}: {
  rows: BloodMarkerRow[]
  protocolType: ProtocolType | null
}) {
  if (rows.length === 0) {
    return (
      <Link href="/dashboard/bloodwork" className="card block text-text-dim text-sm hover:bg-surface-2">
        No bloodwork yet. Add a panel →
      </Link>
    )
  }
  const latest = latestByMarker(rows)
  const markersToShow = protocolType
    ? (PROTOCOL_CONFIGS[protocolType]?.trackedMarkers ?? []).filter(m => latest.has(m)).slice(0, 4)
    : Array.from(latest.keys()).slice(0, 4)

  const allFlags = Array.from(latest.entries()).map(([m, r]) => ({
    marker: m,
    status: statusFor(r.value, r.reference_low, r.reference_high),
  }))
  const outOfRange = allFlags.filter(f => f.status !== 'green' && f.status !== 'unknown')

  const lastDate = Array.from(latest.values())
    .map(r => r.collected_at)
    .sort()
    .reverse()[0]

  return (
    <Link href="/dashboard/bloodwork" className="card block hover:bg-surface-2 transition-colors">
      <div className="flex items-center justify-between mb-2">
        <p className="text-[10px] text-text-muted uppercase tracking-wide">Bloodwork</p>
        <span className="text-[10px] text-text-muted">{lastDate?.slice(0, 10)}</span>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {markersToShow.map(m => {
          const r = latest.get(m)!
          const s = statusFor(r.value, r.reference_low, r.reference_high)
          return (
            <div key={m}>
              <p className="text-[10px] text-text-muted">{m}</p>
              <p className={`text-sm font-semibold ${statusColour(s)}`}>{r.value}</p>
            </div>
          )
        })}
      </div>
      {outOfRange.length > 0 && (
        <p className="text-[10px] text-amber-400 mt-2">
          {outOfRange.length} marker{outOfRange.length === 1 ? '' : 's'} outside reference range
        </p>
      )}
    </Link>
  )
}
