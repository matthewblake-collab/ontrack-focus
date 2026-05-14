'use client'

import { markerLabel, statusColour, statusFor, type BloodMarkerRow } from '../_lib/bloodMarkers'
import type { ProtocolType } from '../_lib/protocolConfig'
import { PROTOCOL_CONFIGS } from '../_lib/protocolConfig'

export function FlagSummary({
  protocolType,
  latestByMarker,
}: {
  protocolType: ProtocolType | null
  latestByMarker: Map<string, BloodMarkerRow>
}) {
  if (!protocolType) return null
  const markers = PROTOCOL_CONFIGS[protocolType]?.trackedMarkers ?? []
  if (markers.length === 0) return null

  const flagged = markers
    .map(m => {
      const row = latestByMarker.get(m)
      if (!row) return null
      const s = statusFor(row.value, row.reference_low, row.reference_high)
      return { marker: m, row, status: s }
    })
    .filter((x): x is NonNullable<typeof x> => x !== null)

  const outOfRange = flagged.filter(f => f.status !== 'green' && f.status !== 'unknown')
  const missing = markers.filter(m => !latestByMarker.has(m))

  return (
    <div className="card">
      <p className="text-[10px] text-text-muted uppercase tracking-wide mb-2">
        Protocol-aware flags · {PROTOCOL_CONFIGS[protocolType]?.displayName}
      </p>
      {outOfRange.length === 0 && missing.length === 0 && (
        <p className="text-sm text-green-400">All tracked markers in range.</p>
      )}
      {outOfRange.length > 0 && (
        <ul className="space-y-1 text-xs">
          {outOfRange.map(f => (
            <li key={f.marker} className={statusColour(f.status)}>
              <span className="font-medium">{markerLabel(f.marker)}:</span>{' '}
              {f.row.value} {f.row.units ?? ''} (ref {f.row.reference_low ?? '·'}–{f.row.reference_high ?? '·'})
            </li>
          ))}
        </ul>
      )}
      {missing.length > 0 && (
        <p className="text-[10px] text-text-muted mt-2">
          Not yet measured: {missing.map(markerLabel).join(', ')}
        </p>
      )}
    </div>
  )
}
