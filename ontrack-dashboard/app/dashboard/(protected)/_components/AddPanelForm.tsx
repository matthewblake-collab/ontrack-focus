'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { markerLabel, markerUnits } from '../_lib/bloodMarkers'
import type { ProtocolType } from '../_lib/protocolConfig'
import { PROTOCOL_CONFIGS } from '../_lib/protocolConfig'

const FALLBACK_MARKERS = [
  'total_t', 'free_t', 'e2', 'lh', 'fsh', 'haematocrit', 'igf1', 'prolactin', 'psa', 'creatinine',
  'glucose', 'hba1c', 'insulin', 'total_chol', 'hdl', 'ldl', 'crp', 'tsh', 'ferritin', 'iron', 'cortisol',
]

export function AddPanelForm({
  userId,
  protocolType,
  onSaved,
}: {
  userId: string
  protocolType: ProtocolType | null
  onSaved: () => void
}) {
  const [open, setOpen] = useState(false)
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [label, setLabel] = useState('')
  const [values, setValues] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const markers = protocolType
    ? Array.from(new Set([...(PROTOCOL_CONFIGS[protocolType]?.trackedMarkers ?? []), ...FALLBACK_MARKERS]))
    : FALLBACK_MARKERS

  async function save() {
    setSaving(true)
    setError(null)
    const supabase = createClient()
    const rows = Object.entries(values)
      .filter(([, v]) => v !== '' && !isNaN(Number(v)))
      .map(([marker, v]) => ({
        user_id: userId,
        marker,
        value: Number(v),
        units: markerUnits(marker, null) || null,
        collected_at: `${date}T00:00:00Z`,
        notes: label || null,
      }))
    if (rows.length === 0) {
      setSaving(false)
      setError('Enter at least one marker value.')
      return
    }
    const { error: supaError } = await supabase
      .from('blood_markers')
      .upsert(rows, { onConflict: 'user_id,marker,collected_at', ignoreDuplicates: false })
    setSaving(false)
    if (supaError) {
      setError(supaError.message)
      return
    }
    setValues({})
    setLabel('')
    setOpen(false)
    onSaved()
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="btn-primary text-sm">
        + Add blood panel
      </button>
    )
  }

  return (
    <div className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4">
      <div className="card w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Add blood panel</h3>
          <button onClick={() => setOpen(false)} className="text-text-muted hover:text-white text-sm">
            Close
          </button>
        </div>
        <div className="space-y-3">
          <label className="block">
            <span className="text-xs text-text-dim">Draw date</span>
            <input type="date" className="input mt-1" value={date} onChange={e => setDate(e.target.value)} />
          </label>
          <label className="block">
            <span className="text-xs text-text-dim">Label (lab name, panel name)</span>
            <input className="input mt-1" value={label} onChange={e => setLabel(e.target.value)} placeholder="e.g. iMedical Sydney — TRT week 5" />
          </label>
          <div className="grid grid-cols-2 gap-2 pt-2">
            {markers.map(m => (
              <label key={m} className="block">
                <span className="text-[10px] text-text-muted">{markerLabel(m)}</span>
                <input
                  type="number"
                  step="any"
                  className="input mt-0.5 text-sm"
                  placeholder={markerUnits(m, null)}
                  value={values[m] ?? ''}
                  onChange={e => setValues(v => ({ ...v, [m]: e.target.value }))}
                />
              </label>
            ))}
          </div>
          {error && <p className="text-xs text-red-400">{error}</p>}
          <button onClick={save} disabled={saving} className="btn-primary w-full">
            {saving ? 'Saving…' : 'Save panel'}
          </button>
        </div>
      </div>
    </div>
  )
}
