'use client'

import { MARKER_INFO, markerLabel, type BloodMarkerRow } from '../_lib/bloodMarkers'
import type { ProtocolType } from '../_lib/protocolConfig'
import { MarkerTrendChart } from './MarkerTrendChart'

export function MarkerDrawer({
  marker,
  rows,
  protocolType,
  onClose,
}: {
  marker: string | null
  rows: BloodMarkerRow[]
  protocolType: ProtocolType | null
  onClose: () => void
}) {
  if (!marker) return null
  const info = MARKER_INFO[marker]
  const protocolContext = info?.protocolContext && protocolType ? info.protocolContext[protocolType] : undefined

  return (
    <div className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4">
      <div className="card w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">{markerLabel(marker)}</h3>
          <button onClick={onClose} className="text-text-muted hover:text-white text-sm">
            Close
          </button>
        </div>
        {info && (
          <>
            <p className="text-sm text-text-dim mb-3">{info.description}</p>
            {protocolContext && (
              <div className="card border-l-2 border-accent/60 mb-3 bg-accent/5">
                <p className="text-[10px] text-accent uppercase tracking-wide mb-1">
                  Context for {protocolType?.replace('_', ' ')}
                </p>
                <p className="text-xs text-text-dim">{protocolContext}</p>
              </div>
            )}
          </>
        )}
        <MarkerTrendChart marker={marker} rows={rows} />
        <p className="text-[10px] text-text-muted mt-3">
          {rows.length} historical draw{rows.length === 1 ? '' : 's'} from{' '}
          {rows[0]?.collected_at.slice(0, 10)} to{' '}
          {rows[rows.length - 1]?.collected_at.slice(0, 10)}
        </p>
      </div>
    </div>
  )
}
