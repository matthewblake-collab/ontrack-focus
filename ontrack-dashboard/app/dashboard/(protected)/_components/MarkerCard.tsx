'use client'

import type { BloodMarkerRow } from '../_lib/bloodMarkers'
import { markerLabel, markerUnits, statusBg, statusColour, statusFor } from '../_lib/bloodMarkers'

export function MarkerCard({
  marker,
  latest,
  onClick,
  highlighted,
}: {
  marker: string
  latest: BloodMarkerRow | null
  onClick: () => void
  highlighted?: boolean
}) {
  const label = markerLabel(marker)
  if (!latest) {
    return (
      <button
        onClick={onClick}
        className={`card text-left w-full ${highlighted ? 'border-accent/40' : ''}`}
      >
        <p className="text-xs text-text-muted">{label}</p>
        <p className="text-text-muted text-sm mt-1">No data</p>
      </button>
    )
  }
  const status = statusFor(latest.value, latest.reference_low, latest.reference_high)
  return (
    <button
      onClick={onClick}
      className={`card text-left w-full border ${statusBg(status)} hover:opacity-90 transition-opacity ${
        highlighted ? 'ring-1 ring-accent/40' : ''
      }`}
    >
      <p className="text-xs text-text-muted">{label}</p>
      <p className={`text-xl font-semibold mt-1 ${statusColour(status)}`}>
        {latest.value}
        <span className="text-[10px] text-text-muted ml-1">{markerUnits(marker, latest.units)}</span>
      </p>
      {(latest.reference_low !== null || latest.reference_high !== null) && (
        <p className="text-[10px] text-text-muted mt-1">
          ref {latest.reference_low ?? '·'}–{latest.reference_high ?? '·'}
        </p>
      )}
    </button>
  )
}
